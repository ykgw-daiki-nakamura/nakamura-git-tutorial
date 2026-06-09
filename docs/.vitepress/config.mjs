import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid({
  title: 'nakamura-git-tutorial',
  description: 'Git / GitHub 実践チュートリアル',
  lang: 'ja-JP',
  themeConfig: {
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
    docFooter: { prev: '前のページ', next: '次のページ' },
    outline: { label: 'このページの内容' }
  },
  mermaid: {}
})
