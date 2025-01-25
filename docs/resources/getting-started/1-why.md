---
prev: false
next:
    text: Installation
    link: ./2-installation/
---

# Why

Skilift is a lockless library with transactions included. It's built on a different model that makes it possible to easily support transactions and edit the same key on multiple different servers by using atomic operations.

It's mental model is different from other libraries, as skilift is built around the idea that you reconcile data into your game constantly where skilift acts as a source-of-truth. This makes it safer than other libraries.
