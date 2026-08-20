// ボールスキン定義。すべて累計コイン(totalCoins)で解放され、課金要素はない。
// 選択中スキンのIDだけをlocalStorageに保存する(解放状態はtotalCoinsから毎回計算するため保存不要)。

export const SKINS = [
  { id: 'classic', label: 'クラシック', unlockCoins: 0, colors: ['#ff5a5f', '#ffffff', '#ffd447', '#ffffff', '#4cc3ff', '#ffffff'] },
  { id: 'candy', label: 'ペパーミント', unlockCoins: 0, colors: ['#ff6fa5', '#ffffff', '#ff6fa5', '#ffffff'] },
  { id: 'sunset', label: 'サンセット', unlockCoins: 50, colors: ['#ff7a3c', '#ffffff', '#ff3c6e', '#ffffff'] },
  { id: 'forest', label: 'フォレスト', unlockCoins: 150, colors: ['#2f8f52', '#ffffff', '#8fe3a0', '#ffffff'] },
  { id: 'galaxy', label: 'ギャラクシー', unlockCoins: 400, colors: ['#5b3cff', '#ffffff', '#38c6ff', '#ffffff'] },
  { id: 'gold', label: 'ゴールド', unlockCoins: 800, colors: ['#ffd447', '#8a6200', '#ffd447', '#ffffff'] },
];

export const DEFAULT_SKIN_ID = SKINS[0].id;

export function isUnlocked(skin, totalCoins) {
  return totalCoins >= skin.unlockCoins;
}

export function findSkin(id) {
  return SKINS.find((s) => s.id === id);
}
