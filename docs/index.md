---
# https://vitepress.dev/reference/default-theme-home-page
layout: home
pageClass: home
next:
  text: 'Introduction'
  link: '/tut/crash-course/1-introduction'

hero:
  name: "skilift"
  text: Lockless Datastore Library
  tagline: Modern library without session locking for player data.
  image:
    src: /logo.svg
  actions:
    - theme: brand
      text: Learn
      link: /resources/
    - theme: alt
      text: API Reference
      link: /api/skilift/
    - theme: alt
      text: Github
      link: https://github.com/alicesaidhi/skilift
features:
  - title: No session locks
    details: Other servers can freely edit data, and everything remains synced.
  - title: Transactions
    details: Edit multiple sessions at the same time using transactions.
---
