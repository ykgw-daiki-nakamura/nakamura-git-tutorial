import { withMermaid } from 'vitepress-plugin-mermaid'

const siteUrl = 'https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/'
const description = 'Git / GitHub をチーム開発で実践的に使いこなすための図解付きチュートリアル'

// 実習タブ用サイドバー（/hands-on/ と /practice/ で共有する）
const handsOnSidebar = [
  {
    text: '実習（ハンズオン）',
    items: [
      { text: '実習の進め方', link: '/hands-on/' },
      { text: '練習場（サンドボックス）', link: '/practice/' },
      { text: '① ローカルで基本操作', link: '/hands-on/basics-lab' },
      { text: '② ブランチとマージ', link: '/hands-on/branching-lab' },
      { text: '③ コンフリクトを解決する', link: '/hands-on/conflicts-lab' },
      { text: '④ rebase で履歴を整える', link: '/hands-on/rebase-lab' },
      { text: '⑤ GitHub にリモート連携', link: '/hands-on/remote-lab' },
      { text: '⑥ GitHub Flow を一周する', link: '/hands-on/github-flow-lab' },
      { text: '⑦ CI を動かす', link: '/hands-on/ci-lab' },
      { text: '⑧ タグとリリース', link: '/hands-on/release-lab' }
    ]
  }
]

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
      { text: '実習', link: '/hands-on/', activeMatch: '^/(hands-on|practice)/' }
    ],
    // パス別サイドバー: ガイドと実習でメニューを切り替える
    sidebar: {
      '/guide/': [
        {
          text: 'はじめに・基礎',
          items: [
            { text: 'Git / GitHub とは', link: '/guide/introduction' },
            { text: 'セットアップ', link: '/guide/setup' },
            { text: 'Git の基本', link: '/guide/basics' },
            { text: '.gitignore で追跡除外', link: '/guide/gitignore' }
          ]
        },
        {
          text: 'チーム開発の基本フロー',
          items: [
            { text: 'ブランチとマージ', link: '/guide/branching' },
            { text: 'リモートと GitHub', link: '/guide/remote' },
            { text: 'GitHub Flow', link: '/guide/github-flow' },
            { text: 'Git Flow', link: '/guide/git-flow' },
            { text: 'GitLab Flow', link: '/guide/gitlab-flow' },
            { text: 'ブランチ戦略の使い分け', link: '/guide/branching-strategies' },
            { text: 'プルリクエストとレビュー', link: '/guide/pull-request' }
          ]
        },
        {
          text: '履歴とコンフリクトの扱い',
          items: [
            { text: 'コンフリクト解決', link: '/guide/conflicts' },
            { text: 'rebase と履歴整理', link: '/guide/rebase' },
            { text: 'ブランチ更新: merge か rebase か', link: '/guide/update-branch' },
            { text: 'git stash で一時退避', link: '/guide/stash' }
          ]
        },
        {
          text: '自動化とリリース',
          items: [
            { text: 'CI 連携 (GitHub Actions)', link: '/guide/ci' },
            { text: 'リリースとバージョン管理', link: '/guide/release' },
            { text: '複数バージョンの保守（リリースブランチ）', link: '/guide/release-branches' },
            { text: 'デュアル配布（SaaS + セルフホスト）でのリリース運用', link: '/guide/dual-distribution' }
          ]
        },
        {
          text: '発展',
          items: [
            { text: '顧客カスタマイズとバージョン運用', link: '/guide/customization' }
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
      '/hands-on/': handsOnSidebar,
      '/practice/': handsOnSidebar
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
