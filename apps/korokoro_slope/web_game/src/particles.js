// 軽量パーティクル演出(ダストトレイル/コイン取得/着地)。
// パフォーマンスのため、固定数のTHREE.Spriteをプールして使い回す(生成/破棄しない)。
import * as THREE from 'three';

let dotTexture = null;
function getDotTexture() {
  if (dotTexture) return dotTexture;
  const size = 64;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  dotTexture = new THREE.CanvasTexture(canvas);
  return dotTexture;
}

const GRAVITY = 4;

export class ParticleSystem {
  constructor(scene, { poolSize = 60 } = {}) {
    this.scene = scene;
    this.pool = [];
    this._cursor = 0;
    for (let i = 0; i < poolSize; i++) {
      const material = new THREE.SpriteMaterial({
        map: getDotTexture(),
        transparent: true,
        depthWrite: false,
      });
      const sprite = new THREE.Sprite(material);
      sprite.visible = false;
      scene.add(sprite);
      this.pool.push({ sprite, velocity: new THREE.Vector3(), life: 0, maxLife: 0 });
    }
  }

  /** count個のパーティクルをposition周辺にランダム散布する。 */
  burst({ position, count, color = 0xffffff, speed = 2, size = 0.22, life = 0.45, spread = 1 }) {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const radial = Math.random() * spread;
      const p = this.pool[this._cursor];
      this._cursor = (this._cursor + 1) % this.pool.length;

      p.life = life * (0.7 + Math.random() * 0.6);
      p.maxLife = p.life;
      p.velocity.set(Math.cos(angle) * radial, Math.random() * speed, Math.sin(angle) * radial);
      p.sprite.position.copy(position);
      p.sprite.material.color.setHex(color);
      p.sprite.material.opacity = 1;
      const s = size * (0.7 + Math.random() * 0.6);
      p.sprite.scale.set(s, s, s);
      p.sprite.visible = true;
    }
  }

  update(dt) {
    for (const p of this.pool) {
      if (!p.sprite.visible) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.sprite.visible = false;
        continue;
      }
      p.sprite.position.addScaledVector(p.velocity, dt);
      p.velocity.y -= GRAVITY * dt;
      p.sprite.material.opacity = Math.max(0, p.life / p.maxLife);
    }
  }
}
