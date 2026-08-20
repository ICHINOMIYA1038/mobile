// DOM オーバーレイ(タイトル/HUD/ポーズ/結果)の表示制御。ゲームロジックとは疎結合にし、
// main.js からのイベント購読とデータ更新だけを受け持つ。
export class UI {
  constructor() {
    this.el = {
      title: document.getElementById('overlay-title'),
      titleBest: document.getElementById('title-best-score'),
      btnStart: document.getElementById('btn-start'),
      themePicker: document.getElementById('theme-picker'),
      skinPicker: document.getElementById('skin-picker'),

      hud: document.getElementById('hud'),
      hudCoins: document.getElementById('hud-coin-count'),
      hudDistance: document.getElementById('hud-distance'),
      btnPause: document.getElementById('btn-pause'),

      pause: document.getElementById('overlay-pause'),
      btnResume: document.getElementById('btn-resume'),
      btnQuitFromPause: document.getElementById('btn-quit'),

      result: document.getElementById('overlay-result'),
      resultTitle: document.getElementById('result-title'),
      resultCoins: document.getElementById('result-coins'),
      resultDistance: document.getElementById('result-distance'),
      resultScore: document.getElementById('result-score'),
      resultBestBadge: document.getElementById('result-best-badge'),
      resultStageUnlock: document.getElementById('result-stage-unlock'),
      btnContinue: document.getElementById('btn-continue'),
      btnRetry: document.getElementById('btn-retry'),
      btnTitle: document.getElementById('btn-title'),

      loading: document.getElementById('overlay-loading'),
      btnMute: document.getElementById('btn-mute'),

      tutorialHint: document.getElementById('tutorial-hint'),

      comboPopup: document.getElementById('combo-popup'),
      milestonePopup: document.getElementById('milestone-popup'),
    };
  }

  /** コンボ継続を知らせるポップアップ(何度も連続で呼ばれてもその都度アニメーションし直す)。 */
  showCombo(count, bonus) {
    const el = this.el.comboPopup;
    el.textContent = `コンボ x${count}  +${bonus}`;
    el.classList.remove('show');
    void el.offsetWidth;
    el.classList.add('show');
  }

  /** 走行距離の節目(100mごと)を知らせるポップアップ。 */
  showMilestone(distance) {
    const el = this.el.milestonePopup;
    el.textContent = `${distance}m 到達！`;
    el.classList.remove('show');
    void el.offsetWidth;
    el.classList.add('show');
  }

  showTutorialHint() {
    this.el.tutorialHint.classList.remove('hidden', 'fade-out');
  }

  /** フェードアウトしてから完全に隠す(唐突に消えないように)。 */
  hideTutorialHint() {
    const el = this.el.tutorialHint;
    if (el.classList.contains('hidden')) return;
    el.classList.add('fade-out');
    setTimeout(() => el.classList.add('hidden'), 300);
  }

  setMuteIcon(muted) {
    this.el.btnMute.textContent = muted ? '🔇' : '🔊';
  }

  /**
   * ステージ選択カードを描画する(スキン選択と同様、毎回作り直してイベント委譲で購読する)。
   * stages: [{id, label}](STAGE_ORDER順)、thumbnails: { [id]: dataURL(実写プレビュー) }、
   * state: {selectedTheme, clearedStages, clearDistance}。
   * 直前のステージがclearedStagesに含まれていないステージはロック(🔒+必要距離)で表示し、
   * タップしても選択できないようにする。
   */
  renderStagePicker(stages, thumbnails, { selectedTheme, clearedStages, clearDistance }) {
    this.el.themePicker.innerHTML = '';
    stages.forEach((stage, i) => {
      const unlocked = i === 0 || clearedStages.includes(stages[i - 1].id);
      const btn = document.createElement('button');
      btn.type = 'button';
      const classes = ['theme-card'];
      if (stage.id === selectedTheme) classes.push('active');
      if (!unlocked) classes.push('locked');
      if (thumbnails[stage.id]) classes.push('has-thumbnail');
      btn.className = classes.join(' ');
      btn.dataset.theme = stage.id;
      btn.dataset.unlocked = unlocked ? '1' : '0';
      btn.setAttribute('aria-label', `${stage.label}ステージ`);
      if (thumbnails[stage.id]) btn.style.backgroundImage = `url(${thumbnails[stage.id]})`;

      const label = document.createElement('span');
      label.className = 'theme-card-label';
      label.textContent = stage.label;
      btn.appendChild(label);

      if (!unlocked) {
        const lock = document.createElement('span');
        lock.className = 'theme-card-lock';
        lock.innerHTML = `🔒<br>${clearDistance}m`;
        btn.appendChild(lock);
      }

      this.el.themePicker.appendChild(btn);
    });
  }

  /** ステージ選択カードのクリックを購読する(イベント委譲)。ロック中のカードは無視する。 */
  onThemeSelect(handler) {
    this.el.themePicker.addEventListener('click', (e) => {
      const btn = e.target.closest('.theme-card');
      if (!btn || btn.dataset.unlocked !== '1') return;
      handler(btn.dataset.theme);
    });
  }

  /**
   * スキン選択UIを描画する。skins: [{id,label,unlockCoins,colors}]、
   * state: {selectedId, totalCoins}。ボタンは毎回作り直すため、購読はonSkinSelect側で
   * イベント委譲する(個々のボタンには直接バインドしない)。
   */
  renderSkinPicker(skins, { selectedId, totalCoins }) {
    this.el.skinPicker.innerHTML = '';
    skins.forEach((skin) => {
      const unlocked = totalCoins >= skin.unlockCoins;
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'skin-btn' + (skin.id === selectedId ? ' active' : '') + (unlocked ? '' : ' locked');
      btn.style.background = skin.colors[0];
      btn.dataset.skinId = skin.id;
      btn.dataset.unlocked = unlocked ? '1' : '0';
      btn.setAttribute('aria-label', skin.label);
      if (!unlocked) {
        const badge = document.createElement('span');
        badge.className = 'skin-lock';
        badge.textContent = `🔒${skin.unlockCoins}`;
        btn.appendChild(badge);
      }
      this.el.skinPicker.appendChild(btn);
    });
  }

  /** スキンボタンのクリックを購読する(イベント委譲)。handlerにはskin idが渡る。 */
  onSkinSelect(handler) {
    this.el.skinPicker.addEventListener('click', (e) => {
      const btn = e.target.closest('.skin-btn');
      if (!btn || btn.dataset.unlocked !== '1') return;
      handler(btn.dataset.skinId);
    });
  }

  _show(el) {
    el.classList.remove('hidden');
  }

  _hide(el) {
    el.classList.add('hidden');
  }

  showLoading() {
    this._show(this.el.loading);
  }

  hideLoading() {
    this._hide(this.el.loading);
  }

  showTitle(bestScore) {
    this.el.titleBest.textContent = String(bestScore);
    this._show(this.el.title);
    this._hide(this.el.hud);
    this._hide(this.el.pause);
    this._hide(this.el.result);
  }

  showPlaying() {
    this._hide(this.el.title);
    this._hide(this.el.pause);
    this._hide(this.el.result);
    this._show(this.el.hud);
  }

  showPaused() {
    this._show(this.el.pause);
  }

  hidePaused() {
    this._hide(this.el.pause);
  }

  updateHud({ coins, distance }) {
    this.el.hudCoins.textContent = String(coins);
    this.el.hudDistance.textContent = String(Math.floor(distance));
  }

  showResult({ cleared, coins, distance, score, isBest, canContinue, unlockedStageLabel }) {
    this._hide(this.el.hud);
    this.el.resultTitle.textContent = cleared ? 'ナイスラン！' : 'コースアウト...';
    this._animateCount(this.el.resultCoins, coins, 500);
    this._animateCount(this.el.resultDistance, Math.floor(distance), 600);
    this._animateCount(this.el.resultScore, score, 800);
    this.el.resultBestBadge.classList.toggle('hidden', !isBest);
    if (isBest) {
      // クラスを一度外して再付与し、同じ結果画面を続けて表示してもアニメーションを再生させる。
      this.el.resultBestBadge.classList.remove('pop');
      void this.el.resultBestBadge.offsetWidth;
      this.el.resultBestBadge.classList.add('pop');
    }
    this.el.resultStageUnlock.classList.toggle('hidden', !unlockedStageLabel);
    if (unlockedStageLabel) {
      this.el.resultStageUnlock.textContent = `🔓 「${unlockedStageLabel}」ステージ解放！`;
      this.el.resultStageUnlock.classList.remove('pop');
      void this.el.resultStageUnlock.offsetWidth;
      this.el.resultStageUnlock.classList.add('pop');
    }
    this.el.btnContinue.classList.toggle('hidden', !canContinue);
    this._show(this.el.result);
  }

  /** 0からtargetまでイーズアウトでカウントアップする(結果画面の数字演出)。 */
  _animateCount(el, target, duration) {
    const start = performance.now();
    const step = (now) => {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - t, 3);
      el.textContent = String(Math.round(target * eased));
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }

  on(name, handler) {
    const map = {
      start: this.el.btnStart,
      pause: this.el.btnPause,
      resume: this.el.btnResume,
      quitFromPause: this.el.btnQuitFromPause,
      continue: this.el.btnContinue,
      retry: this.el.btnRetry,
      quitFromResult: this.el.btnTitle,
      mute: this.el.btnMute,
    };
    const target = map[name];
    if (!target) throw new Error(`unknown UI event: ${name}`);
    target.addEventListener('click', handler);
  }
}
