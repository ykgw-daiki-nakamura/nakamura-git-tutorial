import { withMermaid } from 'vitepress-plugin-mermaid'

const siteUrl = 'https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/'
const description = 'Git / GitHub をチーム開発で実践的に使いこなすための図解付きチュートリアル'

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
      { text: 'はじめに', link: '/guide/introduction' }
    ],
    sidebar: [
      {
        text: 'はじめに・基礎',
        items: [
          { text: 'Git / GitHub とは', link: '/guide/introduction' },
          { text: 'セットアップ', link: '/guide/setup' },
          { text: 'Git の基本', link: '/guide/basics' }
        ]
      },
      {
        text: 'チーム開発',
        items: [
          { text: 'ブランチとマージ', link: '/guide/branching' },
          { text: 'リモートと GitHub', link: '/guide/remote' },
          { text: 'GitHub Flow', link: '/guide/github-flow' },
          { text: 'プルリクエストとレビュー', link: '/guide/pull-request' },
          { text: 'コンフリクト解決', link: '/guide/conflicts' },
          { text: 'rebase と履歴整理', link: '/guide/rebase' },
          { text: 'CI 連携 (GitHub Actions)', link: '/guide/ci' }
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
  mermaid: {}
})
