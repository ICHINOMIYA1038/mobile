// 操作入力の抽象化: 端末の傾き(tilt)をメインに、開発機用にドラッグ/キーボードの
// フォールバックを提供する。出力は steer: -1(左) .. 1(右) の正規化値のみ。
// 坂道を下る推進力は物理演算(重力)に任せ、プレイヤーは左右の舵取りに専念する。

// 感度が高すぎる(わずかな傾きで即フルステアになる/センサーの微振動がそのまま反映される)との
// フィードバックを受け、傾き最大角を広げ、さらに毎フレームの生値を直接使わずスムージングと
// 不感帯(デッドゾーン)を挟むことで、指先や手の震え程度では反応しないようにした。
const TILT_MAX_DEG = 36;
const TILT_DEADZONE_DEG = 3;
const TILT_SMOOTHING = 0.18; // 0=即座に反映、1に近いほど滑らかで反応が遅い
const DRAG_MAX_PX = 140;

export class InputController {
  constructor(rootElement) {
    this.steer = 0;
    this.tiltEnabled = false;

    this._keyLeft = false;
    this._keyRight = false;
    this._tiltValue = 0;
    this._tiltTarget = 0;
    this._dragActive = false;
    this._dragStartX = 0;
    this._dragValue = 0;

    this._onTilt = this._onTilt.bind(this);
    this._bindKeyboard();
    this._bindPointer(rootElement);
  }

  /** iOS13+ Safariはユーザー操作(タップ)由来のコールバック内でのみ許可ダイアログを出せる。 */
  async enableTiltIfAvailable() {
    if (typeof DeviceOrientationEvent === 'undefined') return false;

    const requestPermission = DeviceOrientationEvent.requestPermission;
    if (typeof requestPermission === 'function') {
      try {
        const result = await requestPermission();
        if (result !== 'granted') return false;
      } catch (e) {
        return false;
      }
    }

    window.addEventListener('deviceorientation', this._onTilt, { passive: true });
    this.tiltEnabled = true;
    return true;
  }

  _onTilt(event) {
    if (event.gamma === null || event.gamma === undefined) return;
    // 手ブレ程度の微小な傾きは無視する(不感帯)。
    let gamma = Math.abs(event.gamma) < TILT_DEADZONE_DEG ? 0 : event.gamma;
    const clamped = Math.max(-TILT_MAX_DEG, Math.min(TILT_MAX_DEG, gamma));
    this._tiltTarget = clamped / TILT_MAX_DEG;
  }

  _bindKeyboard() {
    window.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') this._keyLeft = true;
      if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') this._keyRight = true;
    });
    window.addEventListener('keyup', (e) => {
      if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') this._keyLeft = false;
      if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') this._keyRight = false;
    });
  }

  _bindPointer(rootElement) {
    const target = rootElement || window;
    target.addEventListener('pointerdown', (e) => {
      this._dragActive = true;
      this._dragStartX = e.clientX;
      this._dragValue = 0;
    });
    window.addEventListener('pointermove', (e) => {
      if (!this._dragActive) return;
      const dx = e.clientX - this._dragStartX;
      this._dragValue = Math.max(-1, Math.min(1, dx / DRAG_MAX_PX));
    });
    const release = () => {
      this._dragActive = false;
      this._dragValue = 0;
    };
    window.addEventListener('pointerup', release);
    window.addEventListener('pointercancel', release);
  }

  /** 毎フレーム呼び出し、最新のsteer値(-1..1)を返す。 */
  update() {
    if (this.tiltEnabled) {
      // 生のセンサー値を即反映せず、なだらかに追従させることでガタつき/過敏さを抑える。
      this._tiltValue += (this._tiltTarget - this._tiltValue) * TILT_SMOOTHING;
    }
    let steer = 0;
    if (this.tiltEnabled) steer += this._tiltValue;
    if (this._dragActive) steer += this._dragValue;
    if (this._keyLeft) steer -= 1;
    if (this._keyRight) steer += 1;
    this.steer = Math.max(-1, Math.min(1, steer));
    return this.steer;
  }
}
