import { withMermaid } from 'vitepress-plugin-mermaid'

const siteUrl = 'https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/'
const description = 'Git / GitHub をチーム開発で実践的に使いこなすための図解付きチュートリアル'

// VitePress（@mdit-vue/shared）の slugify を再現し、最後に NFC 正規化する。
//
// なぜ要るか: 既定の slugify は `str.normalize("NFKD")` で結合文字に分解したあと、
// rCombining（/[̀-ͯ]/ = ラテン文字の結合記号）しか取り除かない。
// 日本語の濁点 U+3099 / 半濁点 U+309A はこの範囲外なので分解されたまま残り、
// 見出しの id が NFD で出力される（「で」→「て」+ U+3099）。
// ブラウザの fragment 照合は Unicode 正規化を行わないため、Markdown に手で書いた
// 合成済みのアンカー（`#…規約`）は id と一致せず、リンクを踏んでもスクロールしない。
// VitePress 自身が出すリンク（アウトライン・permalink）は同じ id から導出されるので
// 気付きにくい。id を NFC に寄せて、手書きアンカーと一致させる。
//
// @mdit-vue/shared は vitepress にバンドルされており import できないため実装を写している。
// 追随漏れは scripts/check-anchors.mjs（`npm run check:anchors`）が実 HTML と突き合わせて検知する。
const rControl = /[\u0000-\u001f]/g
const rSpecial = /[\s~`!@#$%^&*()\-_+=[\]{}|\\;:"'“”‘’<>,.?/]+/g
const rCombining = /[\u0300-\u036F]/g
const slugify = (str) =>
  str
    .normalize('NFKD')
    .replace(rCombining, '')
    .replace(rControl, '')
    .replace(rSpecial, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/^(\d)/, '_$1')
    .toLowerCase()
    .normalize('NFC')

export default withMermaid({
  title: 'nakamura-git-tutorial',
  description,
  lang: 'ja-JP',
  // プロジェクトページ（https://<user>.github.io/nakamura-git-tutorial/）用の base
  base: '/nakamura-git-tutorial/',
  // git のコミット時刻を最終更新日として利用
  lastUpdated: true,
  // head 内の href には base が自動付与されないためフルパスで記述する
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/nakamura-git-tutorial/favicon.svg' }],
    ['meta', { name: 'theme-color', content: '#F05133' }],
    // OGP / Twitter Card
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'ja_JP' }],
    ['meta', { property: 'og:title', content: 'nakamura-git-tutorial' }],
    ['meta', { property: 'og:description', content: description }],
    ['meta', { property: 'og:site_name', content: 'nakamura-git-tutorial' }],
    ['meta', { property: 'og:url', content: siteUrl }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:title', content: 'nakamura-git-tutorial' }],
    ['meta', { name: 'twitter:description', content: description }]
  ],
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'ホーム', link: '/' },
      { text: 'ガイド', link: '/guide/introduction', activeMatch: '^/guide/' },
      { text: '開発規約', link: '/standards/', activeMatch: '^/standards/' }
    ],
    // パス別サイドバー: ガイドと開発規約でメニューを切り替える
    sidebar: {
      '/guide/': [
        {
          text: 'はじめに・基礎',
          items: [
            { text: 'Git / GitHub とは', link: '/guide/introduction' },
            { text: 'Git の基本', link: '/guide/basics' },
            { text: '.gitignore で追跡除外', link: '/guide/gitignore' }
          ]
        },
        {
          text: 'チーム開発の基本フロー',
          items: [
            { text: 'コミットとコミットメッセージ', link: '/guide/commits' },
            { text: 'ブランチとマージ', link: '/guide/branching' },
            { text: 'リモートと GitHub', link: '/guide/remote' },
            { text: 'プルリクエストとレビュー', link: '/guide/pull-request' },
            { text: 'GitHub Flow', link: '/guide/github-flow' },
            { text: 'CI 連携 (GitHub Actions)', link: '/guide/ci' }
          ]
        },
        {
          text: '割り込みとコンフリクトへの対処',
          collapsed: true,
          items: [
            { text: 'コンフリクト解決', link: '/guide/conflicts' },
            { text: 'git stash で一時退避', link: '/guide/stash' }
          ]
        },
        {
          text: 'ブランチ戦略（発展）',
          collapsed: true,
          items: [
            { text: 'ブランチ戦略の使い分け', link: '/guide/branching-strategies' },
            { text: '他のブランチ戦略', link: '/guide/other-flows' }
          ]
        },
        {
          text: 'リリース運用（発展）',
          collapsed: true,
          items: [
            { text: 'リリースとバージョン管理', link: '/guide/release' },
            { text: 'リリースブランチ運用', link: '/guide/release-branches' },
            { text: 'デュアル配布（SaaS + セルフホスト）', link: '/guide/dual-distribution' }
          ]
        },
        {
          text: '付録',
          items: [
            { text: 'コマンド早見表', link: '/guide/commands' },
            { text: 'トラブルシューティング', link: '/guide/troubleshooting' }
          ]
        }
      ],
      '/standards/': [
        {
          text: '基本方針',
          items: [
            { text: '概要・基本方針', link: '/standards/' }
          ]
        },
        {
          text: 'ブランチとバージョン',
          items: [
            { text: 'ブランチ運用', link: '/standards/branching' },
            { text: 'バージョン運用', link: '/standards/versioning' }
          ]
        },
        {
          text: 'リリース・デプロイと障害対応',
          items: [
            { text: 'リリースとデプロイ', link: '/standards/release' },
            { text: '障害対応', link: '/standards/incident' }
          ]
        },
        {
          text: 'セキュリティ',
          items: [
            { text: '依存とサプライチェーン', link: '/standards/supply-chain' }
          ]
        },
        {
          text: '顧客別カスタマイズ',
          items: [
            { text: '顧客別カスタマイズ', link: '/standards/customization' }
          ]
        },
        {
          text: '禁止事項・用語（参照）',
          items: [
            { text: '禁止事項', link: '/standards/anti-patterns' },
            { text: '用語と背景', link: '/standards/glossary' }
          ]
        }
      ]
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/ykgw-daiki-nakamura/nakamura-git-tutorial' }
    ],
    // ローカル全文検索（ビルド時にインデックスを生成）
    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: '検索', buttonAriaLabel: '検索' },
          modal: {
            displayDetails: '詳細を表示',
            resetButtonTitle: '検索をリセット',
            backButtonTitle: '閉じる',
            noResultsText: '見つかりませんでした',
            footer: {
              selectText: '選択',
              navigateText: '移動',
              closeText: '閉じる'
            }
          }
        }
      }
    },
    // 各ページから GitHub の該当 Markdown へ
    editLink: {
      pattern: 'https://github.com/ykgw-daiki-nakamura/nakamura-git-tutorial/edit/main/docs/:path',
      text: 'このページを編集'
    },
    lastUpdated: {
      text: '最終更新',
      formatOptions: { dateStyle: 'medium', timeStyle: 'short' }
    },
    docFooter: { prev: '前のページ', next: '次のページ' },
    outline: { label: 'このページの内容' },
    // 日本語 UI ラベル
    darkModeSwitchLabel: '外観',
    lightModeSwitchTitle: 'ライトモードに切り替え',
    darkModeSwitchTitle: 'ダークモードに切り替え',
    sidebarMenuLabel: 'メニュー',
    returnToTopLabel: 'トップへ戻る'
  },
  mermaid: {},
  // 見出しの id を NFC 正規化する（上の slugify を参照）。
  // markdown-it-anchor が生成する id と、そこから導出されるアウトライン・permalink が揃う。
  markdown: {
    anchor: { slugify }
  },
  // ビルド出力の最適化:
  // Mermaid は各図種のレンダラを動的 import で個別チャンクへ遅延読み込みしており、
  // 常時読み込まれる app チャンク（約 610KB / Mermaid コア相当）だけが 500KB の
  // 既定しきい値を超えて警告を出していた。manualChunks で束ねると Mermaid 本来の
  // 遅延分割を潰し巨大な単一チャンク化してしまうため、ここではしきい値のみを
  // 妥当な値へ引き上げて警告を解消する（分割構成はそのまま温存する）。
  vite: {
    build: {
      chunkSizeWarningLimit: 700
    }
  }
})
