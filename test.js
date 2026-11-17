const fs = require('fs')
const path = require('path')
const { build } = require('./test/helpers')

build('test/fixtures/specifiers')
build('test/fixtures/git-bundle', (t, cwd) => {
  const dep = path.join(cwd, 'build', '_deps', 'git+bundle+dep-src')

  t.ok(fs.existsSync(path.join(dep, 'package.json')), 'fetched package has a package.json')
  t.absent(fs.existsSync(path.join(dep, 'package-lock.json')), 'no lockfile was written')
})
build('test/fixtures/patches')
