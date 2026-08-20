// 効果音・BGMの再生。すべてCC0素材(static/audio/CREDITS.md参照)。
// WebView環境ではユーザー操作(タップ)を起点にしないと再生がブロックされるため、
// 実際の再生開始は "タップしてスタート" のタップハンドラから行う。

const SFX_SOURCES = {
  click: 'audio/sfx/click.mp3',
  coin: 'audio/sfx/coin.mp3',
  fail: 'audio/sfx/fail.mp3',
  success: 'audio/sfx/success.mp3',
  landing: 'audio/sfx/landing.mp3',
  boost: 'audio/sfx/boost.mp3',
};

const STORAGE_KEY = 'korokoro_muted';

class AudioManager {
  constructor() {
    this.muted = this._loadMuted();
    this._sfxTemplates = {};
    for (const [name, src] of Object.entries(SFX_SOURCES)) {
      const el = new Audio(src);
      el.preload = 'auto';
      this._sfxTemplates[name] = el;
    }

    this._bgm = new Audio('audio/bgm.mp3');
    this._bgm.loop = true;
    this._bgm.volume = 0.5;
    this._bgmStarted = false;
  }

  _loadMuted() {
    try {
      return localStorage.getItem(STORAGE_KEY) === '1';
    } catch (e) {
      return false;
    }
  }

  _saveMuted() {
    try {
      localStorage.setItem(STORAGE_KEY, this.muted ? '1' : '0');
    } catch (e) {
      // ignore
    }
  }

  play(name) {
    if (this.muted) return;
    const template = this._sfxTemplates[name];
    if (!template) return;
    // 連続再生(コイン連続取得など)で音が途切れないよう、都度クローンして鳴らす。
    const node = template.cloneNode(true);
    node.volume = 0.7;
    node.play().catch(() => {});
  }

  /**
   * 最初のユーザー操作(タップしてスタート)から呼び出す。既に開始済みなら何もしない
   * (リトライのたびに曲頭へ巻き戻らないようにするため)。
   */
  ensureBgmStarted() {
    if (this._bgmStarted) return;
    this._bgmStarted = true;
    if (this.muted) return;
    this._bgm.play().catch(() => {});
  }

  setMuted(muted) {
    this.muted = muted;
    this._saveMuted();
    if (muted) {
      this._bgm.pause();
    } else if (this._bgmStarted) {
      this._bgm.play().catch(() => {});
    }
  }

  toggleMuted() {
    this.setMuted(!this.muted);
    return this.muted;
  }
}

export const audio = new AudioManager();
