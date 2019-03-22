#!/usr/bin/env node

const zxcvbn = require('zxcvbn')

const result = zxcvbn(process.argv[2])

console.log(JSON.stringify(result))
