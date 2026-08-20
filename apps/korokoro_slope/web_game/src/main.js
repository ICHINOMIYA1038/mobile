import * as THREE from 'three';
import * as CANNON from 'cannon-es';
import { audio } from './audio.js';
import { bridge } from './bridge.js';
import { InputController } from './input.js';
import { UI } from './ui.js';
import {
  CourseGenerator,
  THEMES,
  DEFAULT_THEME,
  PLATFORM_THICKNESS,
  buildThemePreviewScene,
  STAGE_ORDER,
  STAGE_CLEAR_DISTANCE,
  isStageUnlocked,
} from './course.js';
import { BALL_RADIUS, createWorld, createMaterials, createBallBody, raycastGround } from './physics.js';
import { preloadModels } from './models.js';
import { ParticleSystem } from './particles.js';
import { SKINS, DEFAULT_SKIN_ID, isUnlocked, findSkin } from './skins.js';

const FIXED_DT = 1 / 60;
const MAX_SUBSTEPS = 5;
// 坂道を下る自然な推進力(重力由来、slopeDeg 9〜22度で加速度は約2.8〜6.7)に対して舵の力が
// 強すぎ、少し傾けただけで急に横へ飛ぶように感じるとのフィードバックを受けて弱めた(元は34)。
const STEER_FORCE = 20;
const CHECKPOINT_BACK_DISTANCE = 15;
const FAIL_AIRBORNE_SECONDS = 0.9;
const FAIL_ABSOLUTE_Y = -60;
const BEHIND_CULL_MARGIN = 25;
const LANDING_AIRBORNE_THRESHOLD = 0.15;
const DUST_EMIT_INTERVAL = 0.05;
const DUST_MIN_SPEED = 3;
const BOOST_VELOCITY_MULTIPLIER = 1.6;
const BOOST_MIN_VELOCITY_ADD = 4;
const CLOUD_COUNT = 7;
const CLOUD_DRIFT_RANGE = 45;
const SHAKE_DECAY_PER_SEC = 6;
const FOV_BASE = 62;
const FOV_MAX_BONUS = 9;
const FOV_SPEED_DIVISOR = 26;
// コンボ: 直近のコイン取得からこの秒数以内に次のコインを取ると連続扱いにする。
const COMBO_WINDOW = 1.8;
const COMBO_BONUS_PER_COIN = 5;
const COMBO_MAX_TIER = 5;
const MILESTONE_INTERVAL = 100;
// 接地判定(下方向レイキャスト)は、急な下り坂では「実際は足場から外れて自由落下しているのに、
// 坂面をレイがたまたま拾い続けてgrounded扱いになり続ける」ことがある(球のY座標が下り坂の
// 傾斜と近い速度で下降するため)。これに対する保険として、速度が重力加速度どおりに
// 連続して落ち続けている(=どこにも接触していない)フレーム数を別途数え、一定時間続いたら
// レイキャストの結果に関わらず「空中」扱いにする。
const FREEFALL_STREAK_SECONDS = 0.32;
const FREEFALL_MATCH_TOLERANCE = 0.85;
const THEME_STORAGE_KEY = 'korokoro_theme';

function loadSavedTheme() {
  try {
    const saved = localStorage.getItem(THEME_STORAGE_KEY);
    return THEMES[saved] ? saved : DEFAULT_THEME;
  } catch (e) {
    return DEFAULT_THEME;
  }
}

function saveTheme(theme) {
  try {
    localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (e) {
    // ignore
  }
}

const SKIN_STORAGE_KEY = 'korokoro_skin';

function loadSavedSkinId() {
  try {
    return localStorage.getItem(SKIN_STORAGE_KEY) || DEFAULT_SKIN_ID;
  } catch (e) {
    return DEFAULT_SKIN_ID;
  }
}

function saveSkinId(id) {
  try {
    localStorage.setItem(SKIN_STORAGE_KEY, id);
  } catch (e) {
    // ignore
  }
}

const TUTORIAL_STORAGE_KEY = 'korokoro_tutorial_seen';

function hasSeenTutorial() {
  try {
    return localStorage.getItem(TUTORIAL_STORAGE_KEY) === '1';
  } catch (e) {
    return true; // 保存できない環境では毎回出すのを避け、出さない側に倒す。
  }
}

function markTutorialSeen() {
  try {
    localStorage.setItem(TUTORIAL_STORAGE_KEY, '1');
  } catch (e) {
    // ignore
  }
}

/** 空の背景: 上(天頂)ほど濃く、下(水平線側)ほど明るいグラデーション。色はテーマごとに変わる。 */
function createSkyTexture(sky) {
  const canvas = document.createElement('canvas');
  canvas.width = 2;
  canvas.height = 256;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, sky.top);
  gradient.addColorStop(0.55, sky.mid);
  gradient.addColorStop(1, sky.bottom);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** ふわっとした白い雲のスプライト用テクスチャ(中心が濃く、縁がフェードする円形グラデーション)。 */
function createCloudTexture() {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, 'rgba(255,255,255,0.95)');
  gradient.addColorStop(0.55, 'rgba(255,255,255,0.55)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  return new THREE.CanvasTexture(canvas);
}

/** ボール表面: 回転が視覚的にわかるよう経度方向のカラーストライプを敷く(スキンごとに配色が変わる)。 */
function createBallTexture(stripeColors) {
  const stripeWidth = 48;
  const canvas = document.createElement('canvas');
  canvas.width = stripeWidth * stripeColors.length;
  canvas.height = canvas.width / 2;
  const ctx = canvas.getContext('2d');
  stripeColors.forEach((color, i) => {
    ctx.fillStyle = color;
    ctx.fillRect(i * stripeWidth, 0, stripeWidth, canvas.height);
  });
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

class Game {
  constructor() {
    this.root = document.getElementById('scene-root');
    this.ui = new UI();
    this.input = new InputController(this.root);

    this.state = 'loading';
    this.bestScore = 0;
    this.totalCoins = 0;
    this.clearedStages = [];
    this.theme = loadSavedTheme();
    this.themeThumbnails = {};
    this.skinId = DEFAULT_SKIN_ID;
    this.tutorialActive = false;

    this.distanceTraveled = 0;
    this.coinsThisRun = 0;
    this.continueUsedThisRun = false;
    this.lastGroundY = 0;
    this.airborneTime = 0;
    this.cameraHeading = 0;
    this.shakeStrength = 0;
    this._freefallStreak = 0;
    this._prevVelY = 0;

    this._prevBallPos = new THREE.Vector3();
    this._accumulator = 0;
    this._lastFrameTime = 0;
    this._elapsed = 0;

    this._setupScene();
    this._setupUiEvents();
    window.addEventListener('resize', () => this._onResize());
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && this.state === 'playing') this._pause();
    });
  }

  async start() {
    this.ui.showLoading();
    const [save] = await Promise.all([bridge.loadSave(), preloadModels()]);
    if (save && typeof save === 'object') {
      this.bestScore = Number(save.bestScore) || 0;
      this.totalCoins = Number(save.totalCoins) || 0;
      this.clearedStages = Array.isArray(save.clearedStages) ? save.clearedStages : [];
    }
    // 保存されていた選択ステージが(セーブ破損等で)未解放になっていたら先頭ステージへ戻す。
    // this.courseはこの後_setupPhysics()で作られるため、ここではthis.themeの補正だけでよい。
    if (!isStageUnlocked(this.theme, this.clearedStages)) {
      this.theme = STAGE_ORDER[0];
    }
    this._setupPhysics();
    this._resolveSavedSkin();
    this.themeThumbnails = this._renderThemeThumbnails();
    await bridge.ready();
    this.ui.hideLoading();
    this.ui.setMuteIcon(audio.muted);
    this._refreshTitleSkins();
    this._refreshStagePicker();
    this.ui.showTitle(this.bestScore);
    this.state = 'title';
    this._lastFrameTime = performance.now();
    requestAnimationFrame((t) => this._loop(t));
  }

  _setupScene() {
    this.scene = new THREE.Scene();
    // 空/霧/光/雲の実際の色はテーマ依存なので、_applyThemeAtmosphere()でまとめて設定する
    // (ここでは箱だけ用意する)。
    this.scene.fog = new THREE.Fog(0xffffff, 25, 85);

    this.camera = new THREE.PerspectiveCamera(
      FOV_BASE,
      window.innerWidth / window.innerHeight,
      0.1,
      200,
    );
    this.camera.position.set(0, 6, 9);

    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.VSMShadowMap;
    this.root.appendChild(this.renderer.domElement);

    const ambient = new THREE.AmbientLight(0xffffff, 0.65);
    this.scene.add(ambient);
    this.ambient = ambient;
    const sun = new THREE.DirectionalLight(0xffffff, 0.9);
    sun.position.set(6, 12, 4);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.left = -14;
    sun.shadow.camera.right = 14;
    sun.shadow.camera.top = 14;
    sun.shadow.camera.bottom = -14;
    sun.shadow.camera.near = 1;
    sun.shadow.camera.far = 40;
    sun.shadow.bias = -0.0025;
    this.scene.add(sun);
    this.scene.add(sun.target);
    this.sun = sun;

    this.particles = new ParticleSystem(this.scene);
    this._setupClouds();
    this._applyThemeAtmosphere(this.theme);

    const ballGeometry = new THREE.SphereGeometry(BALL_RADIUS, 24, 18);
    const ballMaterial = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: createBallTexture(findSkin(this.skinId).colors),
      roughness: 0.35,
      metalness: 0.15,
    });
    this.ballMesh = new THREE.Mesh(ballGeometry, ballMaterial);
    this.ballMesh.castShadow = true;
    this.scene.add(this.ballMesh);
  }

  _setupPhysics() {
    this.world = createWorld();
    const { ballMaterial, groundMaterial } = createMaterials(this.world);
    this.course = new CourseGenerator({ scene: this.scene, world: this.world, groundMaterial, theme: this.theme });
    this.course.reset();

    const spawn = this.course.spawnPosition;
    this.ballBody = createBallBody(ballMaterial, spawn);
    this.world.addBody(this.ballBody);
    this._prevBallPos.set(spawn.x, spawn.y, spawn.z);
  }

  _setupUiEvents() {
    this.ui.on('start', () => this._onStartTapped());
    this.ui.on('pause', () => this._pause());
    this.ui.on('resume', () => this._resume());
    this.ui.on('quitFromPause', () => this._quitToTitle());
    this.ui.on('retry', () => this._onRetryTapped());
    this.ui.on('continue', () => this._onContinueTapped());
    this.ui.on('quitFromResult', () => this._quitToTitle());
    this.ui.on('mute', () => this.ui.setMuteIcon(audio.toggleMuted()));
    this.ui.onThemeSelect((theme) => this._onThemeSelected(theme));
    this.ui.onSkinSelect((id) => this._onSkinSelected(id));
  }

  _onThemeSelected(theme) {
    if (theme === this.theme || !THEMES[theme]) return;
    if (!isStageUnlocked(theme, this.clearedStages)) return;
    audio.play('click');
    this.theme = theme;
    this.course.setTheme(theme);
    this._applyThemeAtmosphere(theme);
    saveTheme(theme);
    this._refreshStagePicker();
  }

  /** ステージ選択カード(タイトル画面)を、サムネイル・選択中・ロック状態込みで再描画する。 */
  _refreshStagePicker() {
    this.ui.renderStagePicker(
      STAGE_ORDER.map((id) => ({ id, label: THEMES[id].label })),
      this.themeThumbnails,
      { selectedTheme: this.theme, clearedStages: this.clearedStages, clearDistance: STAGE_CLEAR_DISTANCE },
    );
  }

  /** 空/霧/光/雲の色をテーマに合わせて差し替える(起動時とテーマ切り替え時の両方から呼ぶ)。 */
  _applyThemeAtmosphere(theme) {
    const cfg = THEMES[theme];
    if (this.scene.background && this.scene.background.dispose) this.scene.background.dispose();
    this.scene.background = createSkyTexture(cfg.sky);
    this.scene.fog.color.set(cfg.fogColor);
    this.ambient.color.set(cfg.lightTint ?? 0xffffff);
    const cloudTint = cfg.cloudTint ?? 0xffffff;
    for (const cloud of this.clouds) cloud.sprite.material.color.set(cloudTint);
  }

  /** 起動時、保存済みスキンが現在の累計コインでまだ解放済みかを確認してから適用する。 */
  _resolveSavedSkin() {
    const savedId = loadSavedSkinId();
    const skin = findSkin(savedId);
    this.skinId = skin && isUnlocked(skin, this.totalCoins) ? savedId : DEFAULT_SKIN_ID;
    this._applyBallSkin(this.skinId);
  }

  _refreshTitleSkins() {
    this.ui.renderSkinPicker(SKINS, { selectedId: this.skinId, totalCoins: this.totalCoins });
  }

  _onSkinSelected(id) {
    const skin = findSkin(id);
    if (!skin || !isUnlocked(skin, this.totalCoins) || id === this.skinId) return;
    audio.play('click');
    this.skinId = id;
    saveSkinId(id);
    this._applyBallSkin(id);
    this._refreshTitleSkins();
  }

  _applyBallSkin(id) {
    const skin = findSkin(id) || SKINS[0];
    const material = this.ballMesh.material;
    if (material.map) material.map.dispose();
    material.map = createBallTexture(skin.colors);
    material.needsUpdate = true;
  }

  async _onStartTapped() {
    audio.play('click');
    audio.ensureBgmStarted();
    await this.input.enableTiltIfAvailable();
    this._beginRun();
  }

  _beginRun() {
    this.course.reset();
    const spawn = this.course.spawnPosition;
    this.ballBody.position.set(spawn.x, spawn.y, spawn.z);
    this.ballBody.velocity.set(0, 0, 0);
    this.ballBody.angularVelocity.set(0, 0, 0);
    this._prevBallPos.set(spawn.x, spawn.y, spawn.z);

    this.distanceTraveled = 0;
    this.coinsThisRun = 0;
    this.continueUsedThisRun = false;
    this.lastGroundY = spawn.y;
    this.airborneTime = 0;
    this.cameraHeading = 0;
    this._elapsed = 0;
    this._freefallStreak = 0;
    this._prevVelY = 0;
    this.comboCount = 0;
    this.comboTimer = Infinity;
    this.comboBonus = 0;
    this.lastMilestone = 0;

    this.state = 'playing';
    this.ui.showPlaying();

    this.tutorialActive = !hasSeenTutorial();
    if (this.tutorialActive) this.ui.showTutorialHint();
  }

  _dismissTutorial() {
    if (!this.tutorialActive) return;
    this.tutorialActive = false;
    markTutorialSeen();
    this.ui.hideTutorialHint();
  }

  _pause() {
    if (this.state !== 'playing') return;
    audio.play('click');
    this.state = 'paused';
    this._dismissTutorial();
    this.ui.showPaused();
  }

  _resume() {
    if (this.state !== 'paused') return;
    audio.play('click');
    this.state = 'playing';
    this.ui.hidePaused();
  }

  _quitToTitle() {
    audio.play('click');
    this.state = 'title';
    this._refreshTitleSkins();
    this._refreshStagePicker();
    this.ui.showTitle(this.bestScore);
  }

  async _onRetryTapped() {
    audio.play('click');
    this.state = 'ad-wait';
    await bridge.requestInterstitial('retry');
    this._beginRun();
  }

  async _onContinueTapped() {
    audio.play('click');
    this.state = 'ad-wait';
    const result = await bridge.requestRewarded('continue');
    if (result && result.granted) {
      this._respawnAtCheckpoint();
    } else {
      this.state = 'result';
    }
  }

  _respawnAtCheckpoint() {
    this.continueUsedThisRun = true;
    const checkpointDist = Math.max(0, this.distanceTraveled - CHECKPOINT_BACK_DISTANCE);
    const segment = this.course.segments.find(
      (s) => checkpointDist >= s.startDist && checkpointDist <= s.endDist,
    );
    const spawn = this.course.spawnPosition;
    let x = spawn.x;
    let y = spawn.y;
    let z = spawn.z;
    if (segment) {
      const t = (checkpointDist - segment.startDist) / Math.max(0.001, segment.endDist - segment.startDist);
      y = segment.startY + (segment.endY - segment.startY) * t + PLATFORM_THICKNESS / 2 + 0.9;
      x = this.ballBody.position.x;
      z = this.ballBody.position.z;
    }
    this.ballBody.position.set(x, y, z);
    this.ballBody.velocity.set(0, 0, 0);
    this.ballBody.angularVelocity.set(0, 0, 0);
    this.lastGroundY = y;
    this.airborneTime = 0;
    this._freefallStreak = 0;
    this._prevVelY = 0;
    this.state = 'playing';
    this.ui.showPlaying();
  }

  async _endRun() {
    this._dismissTutorial();
    const score = Math.floor(this.distanceTraveled) + this.coinsThisRun * 15 + this.comboBonus;
    const isBest = score > this.bestScore;
    if (isBest) this.bestScore = score;
    this.totalCoins += this.coinsThisRun;

    // このランでSTAGE_CLEAR_DISTANCE以上走れば、このステージは「クリア」扱いとなり
    // 次のステージ(STAGE_ORDER上で1つ後ろ)が解放される。
    const stageJustCleared =
      this.distanceTraveled >= STAGE_CLEAR_DISTANCE && !this.clearedStages.includes(this.theme);
    if (stageJustCleared) this.clearedStages = [...this.clearedStages, this.theme];
    const nextStageId = STAGE_ORDER[STAGE_ORDER.indexOf(this.theme) + 1];
    const unlockedStageLabel = stageJustCleared && nextStageId ? THEMES[nextStageId].label : null;

    audio.play(isBest || stageJustCleared ? 'success' : 'fail');

    this.state = 'result';
    this.ui.showResult({
      cleared: false,
      coins: this.coinsThisRun,
      distance: this.distanceTraveled,
      score,
      isBest,
      canContinue: !this.continueUsedThisRun,
      unlockedStageLabel,
    });

    bridge.saveProgress({ bestScore: this.bestScore, totalCoins: this.totalCoins, clearedStages: this.clearedStages });
  }

  _onResize() {
    this.camera.aspect = window.innerWidth / window.innerHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(window.innerWidth, window.innerHeight);
  }

  _loop(now) {
    requestAnimationFrame((t) => this._loop(t));
    const dt = Math.min(0.1, (now - this._lastFrameTime) / 1000);
    this._lastFrameTime = now;

    if (this.state === 'playing') {
      this._elapsed += dt;
      this._accumulator += dt;
      let substeps = 0;
      while (this._accumulator >= FIXED_DT && substeps < MAX_SUBSTEPS) {
        this._applySteering();
        this.course.updateMovingPlatforms(this._elapsed);
        this.course.updateCoins(this._elapsed, FIXED_DT);
        this.world.step(FIXED_DT);
        this._accumulator -= FIXED_DT;
        substeps++;
      }
      this._afterPhysicsStep(dt);
    }

    this._syncBallMesh();
    this._updateCamera(dt);
    this._updateSun();
    this._updateClouds(dt);
    this.particles.update(dt);
    this.renderer.render(this.scene, this.camera);
  }

  _updateSun() {
    const p = this.ballMesh.position;
    this.sun.position.set(p.x + 6, p.y + 14, p.z + 6);
    this.sun.target.position.set(p.x, p.y, p.z);
    this.sun.target.updateMatrixWorld();
  }

  /**
   * タイトル画面のコース選択カード用に、各テーマの小さなジオラマをオフスクリーンで実際に
   * レンダリングし、本物の見た目のサムネイル画像(データURL)を作る。色のグラデーションでは
   * なく実写にすることで、カードを見ただけでコースの雰囲気が伝わるようにする。
   * メインの描画とは別のWebGLRendererを使い、生成し終わったら破棄する(一度きりの処理)。
   */
  _renderThemeThumbnails() {
    const size = 240;
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    renderer.setSize(size, size);
    renderer.setPixelRatio(2);
    renderer.shadowMap.enabled = false;

    const camera = new THREE.PerspectiveCamera(36, 1, 0.1, 30);
    camera.position.set(3.6, 3.3, 4.6);
    camera.lookAt(0, 0.2, 0);

    const thumbnails = {};
    for (const theme of Object.keys(THEMES)) {
      const scene = buildThemePreviewScene(theme);
      scene.background = createSkyTexture(THEMES[theme].sky);
      const ambient = new THREE.AmbientLight(0xffffff, 0.8);
      scene.add(ambient);
      const sun = new THREE.DirectionalLight(0xffffff, 0.85);
      sun.position.set(3, 6, 2);
      scene.add(sun);
      renderer.render(scene, camera);
      thumbnails[theme] = renderer.domElement.toDataURL('image/png');
    }

    renderer.dispose();
    renderer.forceContextLoss();
    return thumbnails;
  }

  /** 空に奥行きを出すための雲スプライト。カメラに緩く追従しつつゆっくり流れる(簡易スカイボックス代わり)。 */
  _setupClouds() {
    const cloudTexture = createCloudTexture();
    this.clouds = [];
    for (let i = 0; i < CLOUD_COUNT; i++) {
      const material = new THREE.SpriteMaterial({
        map: cloudTexture,
        transparent: true,
        opacity: 0.75,
        depthWrite: false,
      });
      const sprite = new THREE.Sprite(material);
      const scale = 9 + Math.random() * 7;
      sprite.scale.set(scale * 1.7, scale, 1);
      this.scene.add(sprite);
      this.clouds.push({
        sprite,
        offsetX: (Math.random() - 0.5) * CLOUD_DRIFT_RANGE * 2,
        offsetY: 10 + Math.random() * 12,
        offsetZ: -35 - Math.random() * 45,
        driftSpeed: 0.12 + Math.random() * 0.15,
      });
    }
  }

  _updateClouds(dt) {
    const camPos = this.camera.position;
    for (const cloud of this.clouds) {
      cloud.offsetX += cloud.driftSpeed * dt;
      if (cloud.offsetX > CLOUD_DRIFT_RANGE) cloud.offsetX -= CLOUD_DRIFT_RANGE * 2;
      cloud.sprite.position.set(camPos.x + cloud.offsetX, camPos.y + cloud.offsetY, camPos.z + cloud.offsetZ);
    }
  }

  _applySteering() {
    const steer = this.input.update();
    if (steer === 0) return;
    if (this.tutorialActive) this._dismissTutorial();
    const heading = this.cameraHeading;
    const right = new THREE.Vector3(Math.cos(heading), 0, Math.sin(heading));
    this.ballBody.applyForce(
      new CANNON.Vec3(right.x * steer * STEER_FORCE, 0, right.z * steer * STEER_FORCE),
      this.ballBody.position,
    );
  }

  _afterPhysicsStep(dt) {
    const pos = this.ballBody.position;
    const moved = Math.hypot(pos.x - this._prevBallPos.x, pos.z - this._prevBallPos.z);
    this.distanceTraveled += moved;
    this._prevBallPos.set(pos.x, pos.y, pos.z);

    this.course.ensureAheadOf(this.distanceTraveled);
    this._checkMilestone(pos);

    this.comboTimer += dt;
    const collected = this.course.collectCoins(pos);
    if (collected > 0) {
      this.coinsThisRun += collected;
      audio.play('coin');
      this.particles.burst({
        position: new THREE.Vector3(pos.x, pos.y, pos.z),
        count: collected * 6,
        color: 0xffd447,
        speed: 2.4,
        size: 0.2,
        life: 0.5,
        spread: 1.3,
      });
      this._registerComboPickup(collected);
    }
    this._applyBoostIfEntered(pos);
    this.ui.updateHud({ coins: this.coinsThisRun, distance: this.distanceTraveled });

    const groundY = raycastGround(this.world, pos);
    const raycastGrounded = groundY !== null && pos.y - groundY < 3;
    const grounded = raycastGrounded && !this._updateFreefallStreak(dt);
    if (grounded) {
      this._emitDustTrail(pos, dt);
      if (this.airborneTime > LANDING_AIRBORNE_THRESHOLD) {
        this.particles.burst({
          position: new THREE.Vector3(pos.x, groundY + 0.05, pos.z),
          count: 10,
          color: 0xffffff,
          speed: 1.4,
          size: 0.22,
          life: 0.4,
          spread: 1.6,
        });
        this._triggerCameraShake(this.airborneTime);
        audio.play('landing');
      }
      this.lastGroundY = groundY;
      this.airborneTime = 0;
    } else {
      this.airborneTime += dt;
    }

    const fellTooFar = pos.y < this.lastGroundY - BEHIND_CULL_MARGIN || pos.y < FAIL_ABSOLUTE_Y;
    if (this.airborneTime > FAIL_AIRBORNE_SECONDS || fellTooFar) {
      this._endRun();
    }
  }

  /**
   * レイキャストによる接地判定の弱点(急な下り坂で、実際は足場から外れて自由落下していても
   * 坂面をレイが拾い続けてgrounded扱いのままになりうる)を補う。垂直速度が重力加速度どおりに
   * 連続して減少し続けている(=どこにも接触せず落ち続けている)フレーム数を数え、
   * 一定時間続いたら本当に自由落下中と判断してtrueを返す。
   */
  _updateFreefallStreak(dt) {
    const vy = this.ballBody.velocity.y;
    const expectedDrop = Math.abs(this.world.gravity.y) * dt * FREEFALL_MATCH_TOLERANCE;
    if (this._prevVelY - vy >= expectedDrop) {
      this._freefallStreak += dt;
    } else {
      this._freefallStreak = 0;
    }
    this._prevVelY = vy;
    return this._freefallStreak >= FREEFALL_STREAK_SECONDS;
  }

  _emitDustTrail(pos, dt) {
    const vel = this.ballBody.velocity;
    const speed = Math.hypot(vel.x, vel.z);
    if (speed < DUST_MIN_SPEED) return;
    this._dustTimer = (this._dustTimer || 0) + dt;
    if (this._dustTimer < DUST_EMIT_INTERVAL) return;
    this._dustTimer = 0;
    this.particles.burst({
      position: new THREE.Vector3(pos.x, pos.y - BALL_RADIUS * 0.6, pos.z),
      count: 1,
      color: 0xffffff,
      speed: 0.6,
      size: 0.16,
      life: 0.3,
      spread: 0.35,
    });
  }

  /**
   * コイン取得のコンボ判定。直前の取得からCOMBO_WINDOW秒以内なら連続扱いで加算、
   * 空いていればコンボをリセットしてこの取得数から数え直す。ボーナスは最終スコアに合算する。
   */
  _registerComboPickup(collected) {
    this.comboCount = this.comboTimer <= COMBO_WINDOW ? this.comboCount + collected : collected;
    this.comboTimer = 0;
    const tier = Math.min(COMBO_MAX_TIER, this.comboCount);
    const bonus = collected * tier * COMBO_BONUS_PER_COIN;
    this.comboBonus += bonus;
    if (this.comboCount >= 2) this.ui.showCombo(this.comboCount, bonus);
  }

  /** 走行距離がMILESTONE_INTERVALの倍数を超えるたびに軽い演出を出す。 */
  _checkMilestone(pos) {
    const milestone = Math.floor(this.distanceTraveled / MILESTONE_INTERVAL);
    if (milestone <= this.lastMilestone || milestone === 0) return;
    this.lastMilestone = milestone;
    this.particles.burst({
      position: new THREE.Vector3(pos.x, pos.y + 0.5, pos.z),
      count: 22,
      color: 0xffffff,
      speed: 3,
      size: 0.24,
      life: 0.6,
      spread: 1.6,
    });
    this._triggerCameraShake(0.12);
    this.ui.showMilestone(milestone * MILESTONE_INTERVAL);
  }

  _applyBoostIfEntered(pos) {
    const seg = this.course.consumeBoost(this.distanceTraveled);
    if (!seg) return;
    const vel = this.ballBody.velocity;
    const speed = Math.hypot(vel.x, vel.z);
    const boosted = Math.max(speed * BOOST_VELOCITY_MULTIPLIER, speed + BOOST_MIN_VELOCITY_ADD);
    const scale = speed > 0.01 ? boosted / speed : 1;
    vel.x *= scale;
    vel.z *= scale;
    audio.play('boost');
    this.particles.burst({
      position: new THREE.Vector3(pos.x, pos.y, pos.z),
      count: 16,
      color: 0x38c6ff,
      speed: 3.2,
      size: 0.22,
      life: 0.4,
      spread: 0.5,
    });
  }

  _syncBallMesh() {
    const p = this.ballBody.position;
    const q = this.ballBody.quaternion;
    this.ballMesh.position.set(p.x, p.y, p.z);
    this.ballMesh.quaternion.set(q.x, q.y, q.z, q.w);
  }

  _updateCamera(dt) {
    const vel = this.ballBody.velocity;
    const speed = Math.hypot(vel.x, vel.z);
    if (speed > 1) {
      const targetHeading = Math.atan2(vel.x, -vel.z);
      let diff = targetHeading - this.cameraHeading;
      diff = ((diff + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
      this.cameraHeading += diff * Math.min(1, dt * 2.2);
    }

    // タイトル/結果画面はカード状UIが画面中央〜上寄りを占めるため、ボールがカードの
    // 下に隠れないよう少し引いて見下ろす構図にする(プレイ中は通常のフォロー構図)。
    const isIdle = this.state !== 'playing';
    const backDist = isIdle ? 7 : 7.5;
    const height = isIdle ? 11 : 4.2;
    const back = new THREE.Vector3(-Math.sin(this.cameraHeading), 0, Math.cos(this.cameraHeading));
    const ballPos = this.ballMesh.position;
    const desired = ballPos.clone().add(back.multiplyScalar(backDist)).add(new THREE.Vector3(0, height, 0));

    this.camera.position.lerp(desired, Math.min(1, dt * 4));

    if (this.shakeStrength > 0.001) {
      this.camera.position.x += (Math.random() - 0.5) * this.shakeStrength;
      this.camera.position.y += (Math.random() - 0.5) * this.shakeStrength;
      this.shakeStrength *= Math.exp(-SHAKE_DECAY_PER_SEC * dt);
    } else {
      this.shakeStrength = 0;
    }

    const lookTarget = ballPos.clone().add(new THREE.Vector3(0, isIdle ? -6 : 0.6, 0));
    this.camera.lookAt(lookTarget);

    // スピード感の演出: 速いほど画角を少し広げる(プレイ中のみ、タイトル/結果では通常画角に戻す)。
    const targetFov = isIdle ? FOV_BASE : FOV_BASE + Math.min(FOV_MAX_BONUS, speed * (FOV_MAX_BONUS / FOV_SPEED_DIVISOR));
    if (Math.abs(this.camera.fov - targetFov) > 0.01) {
      this.camera.fov += (targetFov - this.camera.fov) * Math.min(1, dt * 3);
      this.camera.updateProjectionMatrix();
    }
  }

  /** 着地の衝撃でカメラを少し揺らす。airborneTimeが長いほど揺れを大きくする。 */
  _triggerCameraShake(airborneTime) {
    const kick = Math.min(0.35, airborneTime * 0.25);
    this.shakeStrength = Math.max(this.shakeStrength, kick);
  }
}

const game = new Game();
window.__korokoro = game; // デバッグ/QA用に内部状態を参照できるようにする。
game.start();
