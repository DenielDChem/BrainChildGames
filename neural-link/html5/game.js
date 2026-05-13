'use strict';
// ============================================================
//  NEURAL LINK: Drone Operator — HTML5 Prototype v0.1
// ============================================================

// ── CONFIG ───────────────────────────────────────────────────
const CFG = {
  TILE: 20,
  GW: 40,
  GH: 28,

  DRONE_SPEED:    4.0,
  DRONE_VISION:   5,

  ENERGY_MAX:     100,
  ENERGY_REGEN:   4,
  ENERGY_MOVE:    0.35,
  ENERGY_STEALTH: 9,

  COMPUTE_MAX:    100,
  COMPUTE_REGEN:  14,
  COMPUTE_DRAIN:  28,
  PAUSE_TSCALE:   0.12,

  ENEMY_RANGE:    7,
  ENEMY_FOV:      65,
  ENEMY_ROT:      22,
  ENEMY_SWING:    50,
  ENEMY_SPEED:    2.0,
  ENEMY_WAIT:     1.2,
  ENEMY_CHASE_INTERVAL: 0.5,

  DETECT_RATE:    32,
  DETECT_DECAY:   16,

  HACK_RANGE:     1.8,
  HACK_TIME:      4.0,

  BEACON_RADIUS:  7,
  MISSION_TIME:   240,
};

const T = { WALL: 0, FLOOR: 1 };

// ── PALETTE ──────────────────────────────────────────────────
const C = {
  bg:           '#05080f',
  wall:         '#080c18',
  wallLit:      '#0d1530',
  wallEdge:     '#122040',
  floor:        '#0b1225',
  floorLit:     '#0e1a35',
  drone:        '#00e0ff',
  droneGlow:    'rgba(0,224,255,0.35)',
  droneStealth: 'rgba(0,160,200,0.5)',
  path:         'rgba(0,180,220,0.45)',
  waypoint:     'rgba(0,200,240,0.75)',
  enemy:           '#ff2040',
  enemyAlert:      '#ff8800',
  enemySuspicious: '#ffdd00',
  cone:            'rgba(255,28,48,0.22)',
  coneAlert:       'rgba(255,120,20,0.38)',
  coneSuspicious:  'rgba(255,220,0,0.28)',
  coneEdge:        'rgba(255,28,48,0.3)',
  terminal:     '#00ff88',
  termHacked:   '#003322',
  extraction:   '#ffd700',
  beacon:       '#9966ff',
  hudGood:      '#00ff88',
  hudWarn:      '#ffaa00',
  hudBad:       '#ff3344',
  hudText:      '#88bbdd',
  hudTitle:     '#00e0ff',
};

// ── UTILITY ──────────────────────────────────────────────────
const rng    = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const dist   = (ax, ay, bx, by) => Math.sqrt((bx-ax)**2 + (by-ay)**2);
const clamp  = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const toRad  = d => d * Math.PI / 180;

function inBounds(x, y) {
  return x >= 0 && x < CFG.GW && y >= 0 && y < CFG.GH;
}
function angleBetween(ax, ay, bx, by) {
  return Math.atan2(by - ay, bx - ax) * 180 / Math.PI;
}
function angleDelta(a, b) {
  let d = ((a - b) % 360 + 360) % 360;
  return d > 180 ? d - 360 : d;
}

// ── LINE OF SIGHT ────────────────────────────────────────────
function los(map, x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  const steps = Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) * 2.5);
  for (let i = 1; i < steps; i++) {
    const t  = i / steps;
    const tx = Math.round(x1 + dx * t);
    const ty = Math.round(y1 + dy * t);
    if (!inBounds(tx, ty) || map[ty][tx] === T.WALL) return false;
  }
  return true;
}

// ── BSP MAP GENERATION ───────────────────────────────────────
class BSPNode {
  constructor(x, y, w, h) {
    this.x=x; this.y=y; this.w=w; this.h=h;
    this.left=null; this.right=null; this.room=null;
  }
}

function bspSplit(node, minSz, depth) {
  if (depth > 4) return;
  const { w, h } = node;
  if (w < minSz * 2 && h < minSz * 2) return;

  let horiz = Math.random() < 0.5;
  if (w >= h * 1.3) horiz = false;
  if (h >= w * 1.3) horiz = true;

  const span = horiz ? h : w;
  if (span < minSz * 2) return;

  const split = rng(minSz, span - minSz);
  if (horiz) {
    node.left  = new BSPNode(node.x, node.y,         w, split);
    node.right = new BSPNode(node.x, node.y + split, w, h - split);
  } else {
    node.left  = new BSPNode(node.x,         node.y, split,     h);
    node.right = new BSPNode(node.x + split, node.y, w - split, h);
  }
  bspSplit(node.left,  minSz, depth + 1);
  bspSplit(node.right, minSz, depth + 1);
}

function bspCarve(node, map) {
  if (!node.left && !node.right) {
    const m   = 2;
    const mxW = node.w - m * 2;
    const mxH = node.h - m * 2;
    if (mxW < 3 || mxH < 3) return;
    const rw = rng(Math.max(3, mxW - 2), mxW);
    const rh = rng(Math.max(3, mxH - 2), mxH);
    const rx = node.x + rng(m, Math.max(m, node.w - rw - m));
    const ry = node.y + rng(m, Math.max(m, node.h - rh - m));
    node.room = {
      x: rx, y: ry, w: rw, h: rh,
      cx: Math.floor(rx + rw / 2),
      cy: Math.floor(ry + rh / 2),
    };
    for (let y = ry; y < ry + rh; y++)
      for (let x = rx; x < rx + rw; x++)
        if (inBounds(x, y)) map[y][x] = T.FLOOR;
    return;
  }
  if (node.left)  bspCarve(node.left,  map);
  if (node.right) bspCarve(node.right, map);
}

function bspGetRoom(node) {
  if (node.room) return node.room;
  const l = node.left  ? bspGetRoom(node.left)  : null;
  const r = node.right ? bspGetRoom(node.right) : null;
  if (!l) return r;
  if (!r) return l;
  return Math.random() < 0.5 ? l : r;
}

function bspConnect(node, map) {
  if (!node.left || !node.right) return;
  bspConnect(node.left,  map);
  bspConnect(node.right, map);
  const ra = bspGetRoom(node.left);
  const rb = bspGetRoom(node.right);
  if (ra && rb) carveCorridor(map, ra.cx, ra.cy, rb.cx, rb.cy);
}

function carveCorridor(map, x1, y1, x2, y2) {
  let x = x1, y = y1;
  const stamp = (cx, cy) => {
    for (let dy = 0; dy <= 1; dy++)
      for (let dx = 0; dx <= 1; dx++)
        if (inBounds(cx + dx, cy + dy)) map[cy + dy][cx + dx] = T.FLOOR;
  };
  if (Math.random() < 0.5) {
    while (x !== x2) { stamp(x, y); x += x < x2 ? 1 : -1; }
    while (y !== y2) { stamp(x, y); y += y < y2 ? 1 : -1; }
  } else {
    while (y !== y2) { stamp(x, y); y += y < y2 ? 1 : -1; }
    while (x !== x2) { stamp(x, y); x += x < x2 ? 1 : -1; }
  }
  stamp(x, y);
}

function bspCollect(node, arr) {
  if (node.room) { arr.push(node.room); return; }
  if (node.left)  bspCollect(node.left,  arr);
  if (node.right) bspCollect(node.right, arr);
}

// ── A* PATHFINDING ───────────────────────────────────────────
function aStar(map, sx, sy, ex, ey) {
  if (!inBounds(ex, ey) || map[ey][ex] === T.WALL) return null;
  if (sx === ex && sy === ey) return [];

  const K    = (x, y) => y * CFG.GW + x;
  const H    = (x, y) => Math.abs(x - ex) + Math.abs(y - ey);
  const DIRS = [[0,-1],[0,1],[-1,0],[1,0]];

  const open   = new Map();
  const closed = new Set();
  const g      = new Map();
  const f      = new Map();
  const par    = new Map();

  const sk = K(sx, sy);
  g.set(sk, 0); f.set(sk, H(sx, sy));
  open.set(sk, { x: sx, y: sy });

  while (open.size > 0) {
    let ck = null, cf = Infinity;
    for (const k of open.keys()) {
      const fv = f.get(k) ?? Infinity;
      if (fv < cf) { cf = fv; ck = k; }
    }

    const cur = open.get(ck);
    open.delete(ck); closed.add(ck);

    if (cur.x === ex && cur.y === ey) {
      const path = [];
      let k = ck;
      while (k !== sk) {
        path.unshift({ x: k % CFG.GW, y: Math.floor(k / CFG.GW) });
        k = par.get(k);
      }
      return path;
    }

    for (const [dx, dy] of DIRS) {
      const nx = cur.x + dx, ny = cur.y + dy;
      if (!inBounds(nx, ny) || map[ny][nx] === T.WALL) continue;
      const nk = K(nx, ny);
      if (closed.has(nk)) continue;
      const tg = (g.get(ck) ?? 0) + 1;
      if (!open.has(nk) || tg < (g.get(nk) ?? Infinity)) {
        par.set(nk, ck); g.set(nk, tg);
        f.set(nk, tg + H(nx, ny));
        open.set(nk, { x: nx, y: ny });
      }
    }
  }
  return null;
}

// ── DRONE ────────────────────────────────────────────────────
class Drone {
  constructor(x, y) {
    this.gx = x; this.gy = y;
    this.px = x * CFG.TILE + CFG.TILE / 2;
    this.py = y * CFG.TILE + CFG.TILE / 2;
    this.energy       = CFG.ENERGY_MAX;
    this.path         = [];
    this.state        = 'idle';
    this.hackTarget   = null;
    this.hackProgress = 0;
    this.detected     = 0;
    this.alive        = true;
    this.stealthOn    = false;
    this.trail        = [];
  }

  moveTo(map, ex, ey) {
    if (!this.alive) return;
    const p = aStar(map, this.gx, this.gy, ex, ey);
    if (p && p.length > 0) {
      this.path = p;
      this.state = 'moving';
      this.hackTarget = null;
      this.hackProgress = 0;
    }
  }

  update(dt) {
    if (!this.alive) return;

    if (this.state === 'moving' && this.path.length > 0) {
      const tgt = this.path[0];
      const tx  = tgt.x * CFG.TILE + CFG.TILE / 2;
      const ty  = tgt.y * CFG.TILE + CFG.TILE / 2;
      const ddx = tx - this.px, ddy = ty - this.py;
      const d   = Math.sqrt(ddx * ddx + ddy * ddy);
      const spd = CFG.DRONE_SPEED * CFG.TILE * dt;

      if (d <= spd + 0.5) {
        this.px = tx; this.py = ty;
        this.gx = tgt.x; this.gy = tgt.y;
        this.path.shift();
        this.energy = Math.max(0, this.energy - CFG.ENERGY_MOVE);
        if (this.path.length === 0) this.state = 'idle';
      } else {
        this.px += (ddx / d) * spd;
        this.py += (ddy / d) * spd;
      }
      this.trail.push({ x: this.px, y: this.py });
      if (this.trail.length > 18) this.trail.shift();
    }

    if (this.state === 'hacking' && this.hackTarget) {
      this.hackProgress += dt / CFG.HACK_TIME;
      if (this.hackProgress >= 1) {
        this.hackTarget.hacked = true;
        this.hackTarget = null;
        this.hackProgress = 0;
        this.state = 'idle';
        GS.showMsg('Terminal hacked!', 3);
      }
    }

    if (this.state === 'idle')
      this.energy = Math.min(CFG.ENERGY_MAX, this.energy + CFG.ENERGY_REGEN * dt);
    if (this.stealthOn) {
      this.energy = Math.max(0, this.energy - CFG.ENERGY_STEALTH * dt);
      if (this.energy <= 0) {
        this.stealthOn = false;
        GS.showMsg('Stealth offline — power depleted', 2.5);
      }
    }
  }
}

// ── ENEMY ────────────────────────────────────────────────────
class Enemy {
  constructor(x, y, angle, patrolWaypoints = []) {
    this.gx = x; this.gy = y;
    this.px = x * CFG.TILE + CFG.TILE / 2;
    this.py = y * CFG.TILE + CFG.TILE / 2;
    this.angle      = angle;
    this.startAngle = angle;
    this.rotDir     = 1;
    this.alertState = 'patrol';
    this.alertTimer = 0;
    this.flashTimer = 0;

    this.epath            = [];
    this.emoveState       = 'idle';
    this.waitTimer        = CFG.ENEMY_WAIT;
    this.patrolWaypoints  = patrolWaypoints;
    this.patrolIndex      = 0;
    this.lastKnownDrone   = null;
    this.chaseTimer       = 0;
  }

  update(dt) {
    this.flashTimer = Math.max(0, this.flashTimer - dt);

    if (this.alertState === 'alert' && this.lastKnownDrone) {
      this._updateAlert(dt);
    } else if (this.alertState === 'suspicious' && this.lastKnownDrone) {
      this._updateSuspicious();
    } else {
      this._updatePatrol(dt);
    }

    this._moveAlongPath(dt);

    if (this.emoveState === 'moving' && this.epath.length > 0) {
      const tgt = this.epath[0];
      this.angle = angleBetween(this.gx, this.gy, tgt.x, tgt.y);
    } else if (this.emoveState === 'idle') {
      this.angle += CFG.ENEMY_ROT * this.rotDir * dt;
      if (Math.abs(angleDelta(this.angle, this.startAngle)) > CFG.ENEMY_SWING)
        this.rotDir *= -1;
    }
  }

  _updateAlert(dt) {
    this.chaseTimer = Math.max(0, this.chaseTimer - dt);
    if (this.chaseTimer <= 0) {
      const p = aStar(GS.map, this.gx, this.gy, this.lastKnownDrone.x, this.lastKnownDrone.y);
      if (p && p.length > 0) { this.epath = p; this.emoveState = 'moving'; }
      this.chaseTimer = CFG.ENEMY_CHASE_INTERVAL;
    }
  }

  _updateSuspicious() {
    if (this.emoveState === 'idle' && this.lastKnownDrone) {
      const p = aStar(GS.map, this.gx, this.gy, this.lastKnownDrone.x, this.lastKnownDrone.y);
      if (p && p.length > 0) { this.epath = p; this.emoveState = 'moving'; }
      this.lastKnownDrone = null;
    }
  }

  _updatePatrol(dt) {
    if (this.emoveState === 'idle') {
      if (this.waitTimer > 0) {
        this.waitTimer -= dt;
      } else if (this.patrolWaypoints.length > 1) {
        this.patrolIndex = (this.patrolIndex + 1) % this.patrolWaypoints.length;
        const wp = this.patrolWaypoints[this.patrolIndex];
        const p  = aStar(GS.map, this.gx, this.gy, wp.x, wp.y);
        if (p && p.length > 0) { this.epath = p; this.emoveState = 'moving'; }
      }
    }
  }

  _moveAlongPath(dt) {
    if (this.emoveState !== 'moving' || this.epath.length === 0) return;
    const tgt = this.epath[0];
    const tx  = tgt.x * CFG.TILE + CFG.TILE / 2;
    const ty  = tgt.y * CFG.TILE + CFG.TILE / 2;
    const ddx = tx - this.px, ddy = ty - this.py;
    const d   = Math.sqrt(ddx * ddx + ddy * ddy);
    const spd = CFG.ENEMY_SPEED * (this.alertState === 'alert' ? 1.6 : 1.0) * CFG.TILE * dt;

    if (d <= spd + 0.5) {
      this.px = tx; this.py = ty;
      this.gx = tgt.x; this.gy = tgt.y;
      this.epath.shift();
      if (this.epath.length === 0) {
        this.emoveState  = 'idle';
        this.waitTimer   = CFG.ENEMY_WAIT;
        this.startAngle  = this.angle;
      }
    } else {
      this.px += (ddx / d) * spd;
      this.py += (ddy / d) * spd;
    }
  }

  canSee(map, tx, ty) {
    const d = dist(this.gx, this.gy, tx, ty);
    if (d > CFG.ENEMY_RANGE) return false;
    const a = angleBetween(this.gx, this.gy, tx, ty);
    if (Math.abs(angleDelta(a, this.angle)) > CFG.ENEMY_FOV) return false;
    return los(map, this.gx, this.gy, tx, ty);
  }
}

// ── GAME STATE ───────────────────────────────────────────────
const GS = {
  map: [], rooms: [],
  drones: [], enemies: [], terminals: [], beacons: [],
  extraction: null,
  fog: [], fogPerm: [],

  paused: false, compute: CFG.COMPUTE_MAX,
  alertLevel: 0,
  phase: 'active',
  timer: CFG.MISSION_TIME,

  mode: 'move',
  msg: '', msgTimer: 0,
  sonarTimer: 0,
  totalTerminals: 0,

  showMsg(text, dur) {
    this.msg = text;
    this.msgTimer = dur ?? 2.5;
  },
};

// ── WORLD INIT ───────────────────────────────────────────────
function initWorld(attempt = 0) {
  GS.map     = Array.from({ length: CFG.GH }, () => new Array(CFG.GW).fill(T.WALL));
  GS.fog     = Array.from({ length: CFG.GH }, () => new Array(CFG.GW).fill(false));
  GS.fogPerm = Array.from({ length: CFG.GH }, () => new Array(CFG.GW).fill(false));

  const root = new BSPNode(1, 1, CFG.GW - 2, CFG.GH - 2);
  bspSplit(root, 9, 0);
  bspCarve(root, GS.map);
  bspConnect(root, GS.map);

  GS.rooms = [];
  bspCollect(root, GS.rooms);
  if (GS.rooms.length < 3) {
    if (attempt >= 10) throw new Error('BSP failed after 10 attempts');
    initWorld(attempt + 1);
    return;
  }

  // Sort rooms by distance from centre so start is far from extract
  const cx = CFG.GW / 2, cy = CFG.GH / 2;
  GS.rooms.sort((a, b) => dist(a.cx, a.cy, cx, cy) - dist(b.cx, b.cy, cx, cy));

  const startRoom = GS.rooms[0];
  const extRoom   = GS.rooms[GS.rooms.length - 1];

  GS.drones    = [new Drone(startRoom.cx, startRoom.cy)];
  GS.extraction = { x: extRoom.cx, y: extRoom.cy, active: false };

  const midRooms = GS.rooms.filter(r => r !== startRoom && r !== extRoom).slice(0, 3);
  GS.terminals = midRooms.map(r => ({
    x: clamp(r.cx + rng(-1, 1), r.x + 1, r.x + r.w - 2),
    y: clamp(r.cy + rng(-1, 1), r.y + 1, r.y + r.h - 2),
    hacked: false,
  }));
  GS.totalTerminals = GS.terminals.length;

  const enemyRooms = GS.rooms.filter(r => r !== startRoom).slice(0, 5);
  GS.enemies = enemyRooms.map(r => {
    const ex = clamp(r.cx + rng(-1,1), r.x+1, r.x+r.w-2);
    const ey = clamp(r.cy + rng(-1,1), r.y+1, r.y+r.h-2);
    const wp1 = { x: clamp(r.x + rng(1, Math.max(1, r.w-2)), r.x+1, r.x+r.w-2), y: clamp(r.y + rng(1, Math.max(1, r.h-2)), r.y+1, r.y+r.h-2) };
    const wp2 = { x: clamp(r.x + rng(1, Math.max(1, r.w-2)), r.x+1, r.x+r.w-2), y: clamp(r.y + rng(1, Math.max(1, r.h-2)), r.y+1, r.y+r.h-2) };
    return new Enemy(ex, ey, rng(0, 359), [{ x: ex, y: ey }, wp1, wp2]);
  });

  GS.beacons    = [];
  GS.phase      = 'active';
  GS.timer      = CFG.MISSION_TIME;
  GS.alertLevel = 0;
  GS.compute    = CFG.COMPUTE_MAX;
  GS.paused     = false;
  GS.mode       = 'move';
  GS.msg        = '';
  GS.msgTimer   = 0;
  GS.sonarTimer = 0;

  updateFog();
}

// ── FOG OF WAR ───────────────────────────────────────────────
function updateFog() {
  for (let y = 0; y < CFG.GH; y++)
    for (let x = 0; x < CFG.GW; x++)
      GS.fog[y][x] = false;

  for (const d of GS.drones)
    if (d.alive) revealArea(d.gx, d.gy, CFG.DRONE_VISION, false);

  for (const b of GS.beacons)
    revealArea(b.x, b.y, CFG.BEACON_RADIUS, true);
}

function revealArea(cx, cy, radius, permanent) {
  const r = Math.ceil(radius);
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      if (dx*dx + dy*dy > radius*radius) continue;
      const nx = cx + dx, ny = cy + dy;
      if (!inBounds(nx, ny)) continue;
      if (!los(GS.map, cx, cy, nx, ny)) continue;
      GS.fog[ny][nx]     = true;
      GS.fogPerm[ny][nx] = true;
    }
  }
}

// ── UPDATE ───────────────────────────────────────────────────
function update(dt, realDt) {
  if (GS.phase !== 'active') return;

  if (GS.paused) {
    GS.compute = Math.max(0, GS.compute - CFG.COMPUTE_DRAIN * realDt);
    if (GS.compute <= 0) { GS.paused = false; GS.showMsg('Compute buffer empty!', 2); }
  } else {
    GS.compute = Math.min(CFG.COMPUTE_MAX, GS.compute + CFG.COMPUTE_REGEN * realDt);
  }

  GS.timer -= dt;
  if (GS.msgTimer  > 0) GS.msgTimer  -= dt;
  if (GS.sonarTimer > 0) GS.sonarTimer -= dt;

  for (const d of GS.drones)  d.update(dt);
  for (const e of GS.enemies) e.update(dt);

  updateFog();
  checkDetection(dt);
  GS.alertLevel = Math.max(0, GS.alertLevel - 4 * dt);
  checkWinLoss();
}

function checkDetection(dt) {
  const drone = GS.drones[0];
  if (!drone.alive) return;

  let inView = false;
  for (const e of GS.enemies) {
    if (e.canSee(GS.map, drone.gx, drone.gy)) {
      if (!drone.stealthOn) {
        inView = true;
        e.alertState = drone.detected > 45 ? 'alert' : 'suspicious';
        e.alertTimer = 2.5;
        e.flashTimer = 0.4;
        e.lastKnownDrone = { x: drone.gx, y: drone.gy };
      }
    } else {
      if (e.alertTimer > 0) e.alertTimer -= dt;
      else e.alertState = 'patrol';
    }
  }

  if (inView && !drone.stealthOn) {
    drone.detected = Math.min(100, drone.detected + CFG.DETECT_RATE * dt);
    GS.alertLevel  = Math.min(100, GS.alertLevel  + 8  * dt);
  } else {
    drone.detected = Math.max(0, drone.detected - CFG.DETECT_DECAY * dt);
  }
}

function checkWinLoss() {
  const d = GS.drones[0];

  if (GS.alertLevel >= 100) {
    GS.phase = 'failure'; GS.showMsg('LOCKDOWN — maximum alert reached', 5); return;
  }
  if (d.detected >= 100) {
    d.alive = false; GS.phase = 'failure'; GS.showMsg('Drone destroyed by security', 5); return;
  }
  if (GS.timer <= 0) {
    GS.phase = 'failure'; GS.showMsg('Mission timer expired', 5); return;
  }

  const allHacked = GS.terminals.length > 0 && GS.terminals.every(t => t.hacked);
  if (allHacked) GS.extraction.active = true;

  if (allHacked && dist(d.gx, d.gy, GS.extraction.x, GS.extraction.y) < 1.5) {
    GS.phase = 'success'; GS.showMsg('Mission complete — data extracted!', 10);
  }
}

// ── CANVAS ───────────────────────────────────────────────────
let canvas, ctx;

function initCanvas() {
  canvas = document.getElementById('game-canvas');
  canvas.width  = CFG.GW * CFG.TILE;
  canvas.height = CFG.GH * CFG.TILE;
  ctx = canvas.getContext('2d');
}

// ── RENDER ───────────────────────────────────────────────────
function render() {
  ctx.fillStyle = C.bg;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  renderMap();
  renderCones();
  renderFogLayer();
  renderEntities();
  renderWaypoints();
  renderSonar();
  renderOverlayHUD();
  if (GS.phase !== 'active') renderEndScreen();
}

// ── RENDER: MAP ──────────────────────────────────────────────
function renderMap() {
  const ts = CFG.TILE;
  for (let y = 0; y < CFG.GH; y++) {
    for (let x = 0; x < CFG.GW; x++) {
      const vis  = GS.fog[y][x];
      const seen = GS.fogPerm[y][x];
      if (!vis && !seen) continue;

      const px = x * ts, py = y * ts;

      if (GS.map[y][x] === T.WALL) {
        ctx.fillStyle = vis ? C.wallLit : C.wall;
        ctx.fillRect(px, py, ts, ts);
        if (vis) {
          ctx.fillStyle = C.wallEdge;
          ctx.fillRect(px, py, ts, 1);
          ctx.fillRect(px, py, 1, ts);
        }
      } else {
        ctx.fillStyle = vis ? C.floorLit : C.floor;
        ctx.fillRect(px, py, ts, ts);
        if (vis) {
          ctx.strokeStyle = 'rgba(16,40,80,0.3)';
          ctx.lineWidth = 0.5;
          ctx.strokeRect(px + 0.5, py + 0.5, ts - 1, ts - 1);
          ctx.lineWidth = 1;
        }
      }
    }
  }

  // Extraction zone
  const e = GS.extraction;
  if (e && (GS.fog[e.y]?.[e.x] || GS.fogPerm[e.y]?.[e.x])) {
    const px = e.x * ts, py = e.y * ts;
    ctx.fillStyle = e.active ? 'rgba(255,215,0,0.18)' : 'rgba(255,215,0,0.07)';
    ctx.fillRect(px - ts, py - ts, ts*3, ts*3);
    ctx.strokeStyle = e.active ? C.extraction : 'rgba(255,215,0,0.3)';
    ctx.lineWidth = e.active ? 2 : 1;
    ctx.strokeRect(px - ts + 1, py - ts + 1, ts*3 - 2, ts*3 - 2);
    ctx.lineWidth = 1;
    ctx.fillStyle = e.active ? C.extraction : 'rgba(255,215,0,0.35)';
    ctx.font = `bold ${e.active ? 9 : 8}px monospace`;
    ctx.textAlign = 'center';
    ctx.fillText(e.active ? 'EXTRACT' : 'EXT', px + ts/2, py + ts/2 + 3);
  }

  // Terminals
  for (const t of GS.terminals) {
    if (!GS.fog[t.y]?.[t.x] && !GS.fogPerm[t.y]?.[t.x]) continue;
    const px = t.x * ts, py = t.y * ts, pad = 4;
    if (!t.hacked) {
      const pulse = 0.5 + 0.3 * Math.sin(Date.now() / 350);
      ctx.fillStyle = `rgba(0,255,136,${pulse * 0.22})`;
      ctx.fillRect(px+1, py+1, ts-2, ts-2);
    }
    ctx.fillStyle = t.hacked ? '#001a0d' : '#000a05';
    ctx.fillRect(px+pad, py+pad, ts-pad*2, ts-pad*2);
    ctx.strokeStyle = t.hacked ? '#005530' : C.terminal;
    ctx.lineWidth = 1.5;
    ctx.strokeRect(px+pad, py+pad, ts-pad*2, ts-pad*2);
    ctx.lineWidth = 1;
    ctx.fillStyle = t.hacked ? '#006633' : C.terminal;
    ctx.font = 'bold 8px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(t.hacked ? '✓' : 'TRM', px + ts/2, py + ts/2 + 3);

    const drone = GS.drones[0];
    if (drone.hackTarget === t) {
      ctx.fillStyle = '#003311';
      ctx.fillRect(px, py + ts - 4, ts, 4);
      ctx.fillStyle = C.terminal;
      ctx.fillRect(px, py + ts - 4, ts * drone.hackProgress, 4);
    }
  }

  // Beacons
  for (const b of GS.beacons) {
    const px = b.x * ts + ts/2, py = b.y * ts + ts/2;
    ctx.beginPath();
    ctx.arc(px, py, ts/3+1, 0, Math.PI*2);
    ctx.fillStyle = 'rgba(153,102,255,0.4)';
    ctx.fill();
    ctx.strokeStyle = C.beacon;
    ctx.lineWidth = 1.5; ctx.stroke(); ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(px, py, CFG.BEACON_RADIUS * ts, 0, Math.PI*2);
    ctx.strokeStyle = 'rgba(153,102,255,0.15)';
    ctx.stroke();
  }
}

// ── CONE POLYGON (wall-clipped) ──────────────────────────────
function buildConePolygon(e) {
  const RAYS = 32;
  const a0   = e.angle - CFG.ENEMY_FOV;
  const a1   = e.angle + CFG.ENEMY_FOV;
  const maxR = CFG.ENEMY_RANGE * CFG.TILE;
  const STEP = 5;
  const pts  = [{x: e.px, y: e.py}];

  for (let i = 0; i <= RAYS; i++) {
    const ang = toRad(a0 + (a1 - a0) * i / RAYS);
    const ca  = Math.cos(ang), sa = Math.sin(ang);
    let hitX  = e.px + ca * maxR;
    let hitY  = e.py + sa * maxR;

    for (let d = STEP; d <= maxR; d += STEP) {
      const wx = e.px + ca * d;
      const wy = e.py + sa * d;
      const gx = Math.floor(wx / CFG.TILE);
      const gy = Math.floor(wy / CFG.TILE);
      if (!inBounds(gx, gy) || GS.map[gy][gx] === T.WALL) {
        hitX = e.px + ca * Math.max(STEP, d - STEP);
        hitY = e.py + sa * Math.max(STEP, d - STEP);
        break;
      }
    }
    pts.push({x: hitX, y: hitY});
  }
  return pts;
}

// ── RENDER: ENEMY CONES ──────────────────────────────────────
function renderCones() {
  for (const e of GS.enemies) {
    if (!GS.fog[e.gy]?.[e.gx] && !GS.fogPerm[e.gy]?.[e.gx]) continue;
    const alerted    = e.alertState === 'alert';
    const suspicious = e.alertState === 'suspicious';

    const pts = buildConePolygon(e);
    ctx.beginPath();
    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
    ctx.closePath();
    ctx.fillStyle   = alerted ? C.coneAlert : suspicious ? C.coneSuspicious : C.cone;
    ctx.fill();
    ctx.strokeStyle = C.coneEdge;
    ctx.lineWidth = 0.5; ctx.stroke(); ctx.lineWidth = 1;

    ctx.beginPath();
    ctx.arc(e.px, e.py, 7, 0, Math.PI*2);
    ctx.fillStyle   = alerted ? C.enemyAlert : suspicious ? C.enemySuspicious : C.enemy;
    ctx.fill();
    ctx.strokeStyle = alerted ? '#ffcc44' : suspicious ? '#ffe066' : '#ff7090';
    ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1;

    const dx2 = Math.cos(toRad(e.angle)) * 11;
    const dy2 = Math.sin(toRad(e.angle)) * 11;
    ctx.beginPath();
    ctx.moveTo(e.px, e.py); ctx.lineTo(e.px + dx2, e.py + dy2);
    ctx.strokeStyle = alerted ? '#ffcc44' : suspicious ? '#ffe066' : '#ff5070';
    ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1;

    if (e.flashTimer > 0) {
      ctx.beginPath();
      ctx.arc(e.px, e.py, 14, 0, Math.PI*2);
      ctx.strokeStyle = `rgba(255,200,0,${e.flashTimer * 1.8})`;
      ctx.lineWidth = 2.5; ctx.stroke(); ctx.lineWidth = 1;
    }
  }
}

// ── RENDER: DRONE ────────────────────────────────────────────
function renderEntities() {
  const drone = GS.drones[0];
  if (!drone.alive) return;
  const { px, py } = drone;

  if (drone.trail.length > 1) {
    ctx.beginPath();
    ctx.moveTo(drone.trail[0].x, drone.trail[0].y);
    for (let i = 1; i < drone.trail.length; i++)
      ctx.lineTo(drone.trail[i].x, drone.trail[i].y);
    ctx.strokeStyle = C.droneGlow;
    ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1;
  }

  const grd = ctx.createRadialGradient(px, py, 0, px, py, 22);
  grd.addColorStop(0, 'rgba(0,224,255,0.28)');
  grd.addColorStop(1, 'rgba(0,224,255,0)');
  ctx.fillStyle = grd;
  ctx.beginPath(); ctx.arc(px, py, 22, 0, Math.PI*2); ctx.fill();

  ctx.beginPath(); ctx.arc(px, py, 7, 0, Math.PI*2);
  ctx.fillStyle   = drone.stealthOn ? C.droneStealth : C.drone;
  ctx.fill();
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 1.5; ctx.stroke(); ctx.lineWidth = 1;

  if (drone.detected > 0) {
    ctx.beginPath();
    ctx.arc(px, py, 13, -Math.PI/2, -Math.PI/2 + Math.PI*2*drone.detected/100);
    ctx.strokeStyle = drone.detected > 65 ? C.hudBad : C.hudWarn;
    ctx.lineWidth = 2.5; ctx.stroke(); ctx.lineWidth = 1;
  }

  if (drone.state === 'hacking') {
    ctx.beginPath();
    ctx.arc(px, py, 16, -Math.PI/2, -Math.PI/2 + Math.PI*2*drone.hackProgress);
    ctx.strokeStyle = C.terminal;
    ctx.lineWidth = 3; ctx.stroke(); ctx.lineWidth = 1;
  }

  if (drone.stealthOn) {
    ctx.beginPath(); ctx.arc(px, py, 10, 0, Math.PI*2);
    ctx.strokeStyle = 'rgba(0,180,220,0.5)';
    ctx.lineWidth = 1;
    ctx.setLineDash([3,3]); ctx.stroke(); ctx.setLineDash([]); ctx.lineWidth = 1;
  }
}

// ── RENDER: PATH ─────────────────────────────────────────────
function renderWaypoints() {
  const drone = GS.drones[0];
  if (!drone.alive || drone.path.length === 0) return;

  ctx.beginPath();
  ctx.moveTo(drone.px, drone.py);
  for (const pt of drone.path)
    ctx.lineTo(pt.x * CFG.TILE + CFG.TILE/2, pt.y * CFG.TILE + CFG.TILE/2);
  ctx.strokeStyle = C.path;
  ctx.lineWidth = 1.5;
  ctx.setLineDash([5,5]); ctx.stroke(); ctx.setLineDash([]); ctx.lineWidth = 1;

  const last = drone.path[drone.path.length - 1];
  ctx.beginPath();
  ctx.arc(last.x*CFG.TILE+CFG.TILE/2, last.y*CFG.TILE+CFG.TILE/2, 4, 0, Math.PI*2);
  ctx.fillStyle = C.waypoint; ctx.fill();
}

// ── RENDER: FOG ──────────────────────────────────────────────
function renderFogLayer() {
  for (let y = 0; y < CFG.GH; y++) {
    for (let x = 0; x < CFG.GW; x++) {
      if (GS.fog[y][x]) continue;
      ctx.fillStyle = GS.fogPerm[y][x]
        ? 'rgba(0,0,0,0.65)'
        : 'rgba(4,7,14,0.97)';
      ctx.fillRect(x * CFG.TILE, y * CFG.TILE, CFG.TILE, CFG.TILE);
    }
  }
}

// ── RENDER: SONAR ────────────────────────────────────────────
function renderSonar() {
  if (GS.sonarTimer <= 0) return;
  const drone = GS.drones[0];
  if (!drone.alive) return;
  const alpha = Math.min(1, GS.sonarTimer);

  for (const t of GS.terminals) {
    if (t.hacked) continue;
    const tx  = t.x * CFG.TILE + CFG.TILE / 2;
    const ty  = t.y * CFG.TILE + CFG.TILE / 2;
    const dx  = tx - drone.px;
    const dy  = ty - drone.py;
    const d   = Math.sqrt(dx * dx + dy * dy);
    const ang = Math.atan2(dy, dx);
    const ca  = Math.cos(ang), sa = Math.sin(ang);

    if (GS.fog[t.y]?.[t.x]) {
      const pulse = 14 + Math.sin(Date.now() / 150) * 3;
      ctx.beginPath();
      ctx.arc(tx, ty, pulse, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(0,255,136,${alpha * 0.9})`;
      ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1;
    } else {
      const s = 18, len = 36;
      const ex = drone.px + ca * (s + len);
      const ey = drone.py + sa * (s + len);
      ctx.beginPath();
      ctx.moveTo(drone.px + ca * s, drone.py + sa * s);
      ctx.lineTo(ex, ey);
      ctx.strokeStyle = `rgba(0,255,136,${alpha * 0.7})`;
      ctx.lineWidth = 1.5; ctx.stroke(); ctx.lineWidth = 1;

      const hA = 0.45;
      ctx.beginPath();
      ctx.moveTo(ex, ey);
      ctx.lineTo(ex - Math.cos(ang - hA) * 8, ey - Math.sin(ang - hA) * 8);
      ctx.lineTo(ex - Math.cos(ang + hA) * 8, ey - Math.sin(ang + hA) * 8);
      ctx.closePath();
      ctx.fillStyle = `rgba(0,255,136,${alpha * 0.7})`;
      ctx.fill();

      const tiles = Math.round(d / CFG.TILE);
      ctx.fillStyle = `rgba(0,255,136,${alpha * 0.5})`;
      ctx.font = '8px monospace';
      ctx.textAlign = 'center';
      ctx.fillText(`${tiles}`, ex + ca * 10, ey + sa * 10);
    }
  }
}

// ── RENDER: OVERLAY HUD ──────────────────────────────────────
function renderOverlayHUD() {
  const W = canvas.width;

  if (GS.msgTimer > 0 && GS.msg) {
    const alpha = Math.min(1, GS.msgTimer / 0.5);
    const mw = 320, mh = 28, mx = (W-mw)/2, my = canvas.height - 52;
    ctx.fillStyle = `rgba(0,0,0,${alpha*0.72})`;
    ctx.fillRect(mx, my, mw, mh);
    ctx.strokeStyle = `rgba(0,224,255,${alpha*0.6})`;
    ctx.lineWidth = 1; ctx.strokeRect(mx, my, mw, mh); ctx.lineWidth = 1;
    ctx.fillStyle = `rgba(0,224,255,${alpha})`;
    ctx.font = '12px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(GS.msg, mx + mw/2, my + 18);
  }

  if (GS.paused) {
    ctx.fillStyle = 'rgba(0,180,255,0.05)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'rgba(0,10,30,0.65)';
    ctx.fillRect(W/2-95, 7, 190, 26);
    ctx.fillStyle = C.hudTitle;
    ctx.font = 'bold 13px monospace';
    ctx.textAlign = 'center';
    ctx.fillText('TACTICAL PAUSE', W/2, 25);
  }

  const modeCol   = GS.mode === 'beacon' ? C.beacon : C.drone;
  const modeLabel = GS.mode === 'beacon' ? 'BEACON MODE' : 'MOVE MODE';
  ctx.fillStyle = 'rgba(0,0,0,0.6)';
  ctx.fillRect(6, 6, 110, 20);
  ctx.fillStyle = modeCol;
  ctx.font = '10px monospace';
  ctx.textAlign = 'left';
  ctx.fillText(modeLabel, 10, 20);
}

// ── RENDER: END SCREEN ───────────────────────────────────────
function renderEndScreen() {
  const W = canvas.width, H = canvas.height;
  const ok = GS.phase === 'success';
  ctx.fillStyle = 'rgba(0,0,0,0.72)';
  ctx.fillRect(0, 0, W, H);

  const bw = 430, bh = 165, bx = (W-bw)/2, by = (H-bh)/2;
  ctx.fillStyle = ok ? 'rgba(0,255,120,0.1)' : 'rgba(255,30,50,0.1)';
  ctx.fillRect(bx, by, bw, bh);
  ctx.strokeStyle = ok ? C.hudGood : C.hudBad;
  ctx.lineWidth = 2; ctx.strokeRect(bx, by, bw, bh); ctx.lineWidth = 1;

  ctx.fillStyle = ok ? C.hudGood : C.hudBad;
  ctx.font = 'bold 26px monospace';
  ctx.textAlign = 'center';
  ctx.fillText(ok ? 'MISSION COMPLETE' : 'MISSION FAILED', W/2, by+44);

  ctx.fillStyle = C.hudText;
  ctx.font = '13px monospace';
  ctx.fillText(GS.msg, W/2, by+72);

  const hacked = GS.terminals.filter(t => t.hacked).length;
  ctx.fillText(`Terminals: ${hacked} / ${GS.totalTerminals}`, W/2, by+96);
  const elapsed = CFG.MISSION_TIME - GS.timer;
  const em = Math.floor(elapsed/60), es = String(Math.floor(elapsed%60)).padStart(2,'0');
  ctx.fillText(`Time: ${em}:${es}`, W/2, by+118);

  ctx.fillStyle = 'rgba(255,255,255,0.45)';
  ctx.font = '11px monospace';
  ctx.fillText('Press  R  to restart', W/2, by+148);
}

// ── SIDEBAR HUD ──────────────────────────────────────────────
function updateHUD() {
  const drone  = GS.drones[0];
  const hacked = GS.terminals.filter(t => t.hacked).length;

  const setBar = (id, pct, color) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.style.width = clamp(pct, 0, 100) + '%';
    if (color) el.style.background = color;
  };

  const alertCol = GS.alertLevel > 70 ? C.hudBad : GS.alertLevel > 40 ? C.hudWarn : C.hudGood;
  setBar('alert-fill',   GS.alertLevel,                               alertCol);
  const detCol = (drone.alive ? drone.detected : 0) > 70 ? C.hudBad
    : (drone.alive ? drone.detected : 0) > 40 ? C.hudWarn : C.hudGood;
  setBar('detect-fill',  drone.alive ? drone.detected : 0,            detCol);
  setBar('energy-fill',  drone.alive ? drone.energy/CFG.ENERGY_MAX*100 : 0);
  setBar('compute-fill', GS.compute/CFG.COMPUTE_MAX*100);

  const pct = document.getElementById('alert-pct');
  if (pct) pct.textContent = Math.round(GS.alertLevel) + '%';

  const timerEl = document.getElementById('timer-val');
  if (timerEl) {
    const t = Math.max(0, GS.timer);
    timerEl.textContent = `${Math.floor(t/60)}:${String(Math.floor(t%60)).padStart(2,'0')}`;
    timerEl.style.color  = t < 30 ? C.hudBad : C.hudTitle;
  }

  const objEl = document.getElementById('objectives');
  if (objEl) {
    const items = GS.terminals.map((t, i) =>
      `<div class="obj${t.hacked ? ' done' : ''}">${t.hacked ? '✓' : '○'} Terminal ${i+1}</div>`
    ).join('');
    const extDone = GS.phase === 'success';
    const need    = GS.totalTerminals - hacked;
    const extHint = GS.extraction?.active ? '' : ` <span style="color:#2a4060;font-size:9px">(${need} left)</span>`;
    objEl.innerHTML = items +
      `<div class="obj${extDone ? ' done' : ''}">${extDone ? '✓' : '→'} Reach extraction${extHint}</div>`;
  }

  const phaseEl = document.getElementById('phase-status');
  if (phaseEl) {
    const labels = { active:'ACTIVE', success:'SUCCESS', failure:'FAILED' };
    const colors = { active: C.hudText, success: C.hudGood, failure: C.hudBad };
    phaseEl.textContent  = labels[GS.phase];
    phaseEl.style.color  = colors[GS.phase];
  }
}

// ── INPUT ────────────────────────────────────────────────────
function canvasToGrid(cx, cy) {
  const rect = canvas.getBoundingClientRect();
  return {
    x: Math.floor((cx - rect.left) * (canvas.width  / rect.width)  / CFG.TILE),
    y: Math.floor((cy - rect.top)  * (canvas.height / rect.height) / CFG.TILE),
  };
}

function handleMouseDown(e) {
  if (e.button !== 0 || GS.phase !== 'active') return;
  const g = canvasToGrid(e.clientX, e.clientY);
  if (!inBounds(g.x, g.y)) return;
  const drone = GS.drones[0];
  if (!drone.alive) return;

  if (GS.mode === 'move') {
    if (GS.map[g.y][g.x] === T.FLOOR) drone.moveTo(GS.map, g.x, g.y);
  } else if (GS.mode === 'beacon') {
    GS.beacons.push({ x: drone.gx, y: drone.gy });
    updateFog();
    GS.showMsg('Beacon deployed', 2);
    GS.mode = 'move';
  }
}

document.addEventListener('keydown', e => {
  switch (e.code) {
    case 'Space':
      e.preventDefault();
      if (GS.phase !== 'active') break;
      if (!GS.paused) {
        if (GS.compute > 5) GS.paused = true;
        else GS.showMsg('Compute buffer depleted!', 2);
      } else {
        GS.paused = false;
      }
      break;

    case 'KeyE': {
      if (GS.phase !== 'active') break;
      const drone = GS.drones[0];
      if (!drone.alive || drone.state === 'moving') break;
      let best = null, bestD = Infinity;
      for (const t of GS.terminals) {
        if (t.hacked) continue;
        const d = dist(drone.gx, drone.gy, t.x, t.y);
        if (d < bestD) { bestD = d; best = t; }
      }
      if (best && bestD <= CFG.HACK_RANGE) {
        drone.state = 'hacking';
        drone.hackTarget = best;
        drone.hackProgress = 0;
        GS.showMsg('Hacking terminal…', CFG.HACK_TIME + 1);
      } else if (best) {
        GS.showMsg('Move adjacent to terminal first', 2.5);
      } else {
        GS.showMsg('All terminals already hacked', 2);
      }
      break;
    }

    case 'KeyQ':
      if (GS.phase !== 'active') break;
      GS.mode = GS.mode === 'beacon' ? 'move' : 'beacon';
      GS.showMsg(GS.mode === 'beacon'
        ? 'Beacon mode — click to deploy at drone position'
        : 'Move mode', 2);
      break;

    case 'KeyS': {
      if (GS.phase !== 'active') break;
      const drone = GS.drones[0];
      if (!drone.alive) break;
      drone.stealthOn = !drone.stealthOn;
      GS.showMsg(drone.stealthOn ? 'Stealth engaged' : 'Stealth disengaged', 1.5);
      break;
    }

    case 'KeyF':
      if (GS.phase !== 'active') break;
      GS.sonarTimer = 3.5;
      GS.showMsg('Sonar ping — tracking terminals', 2);
      break;

    case 'KeyR':
      if (GS.phase !== 'active') initWorld();
      break;
  }
});

// ── MAIN LOOP ────────────────────────────────────────────────
let lastTime = 0;

function gameLoop(ts) {
  const realDt = Math.min((ts - lastTime) / 1000, 0.1);
  lastTime = ts;
  update(realDt * (GS.paused ? CFG.PAUSE_TSCALE : 1), realDt);
  render();
  updateHUD();
  requestAnimationFrame(gameLoop);
}

// ── INIT ─────────────────────────────────────────────────────
function init() {
  initCanvas();
  initWorld();
  canvas.addEventListener('mousedown', handleMouseDown);
  requestAnimationFrame(gameLoop);
}

window.addEventListener('load', init);
