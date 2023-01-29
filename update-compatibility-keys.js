#!/usr/bin/node

const fs = require("node:fs");

const currentCompatibilityKey = 6;

fs.writeFileSync(
  "src/Pages/Internal/Platform/CompatibilityKey.elm",
  `module Pages.Internal.Platform.CompatibilityKey exposing (currentCompatibilityKey)


currentCompatibilityKey : Int
currentCompatibilityKey =
    ${currentCompatibilityKey}
`
);

fs.writeFileSync(
  "generator/src/compatibility-key.js",
  `module.exports = { compatibilityKey: ${currentCompatibilityKey} };
`
);

fs.writeFileSync(
  "./README.md",
  fs
    .readFileSync("./README.md")
    .toString()
    .replace(
      /Current Compatibility Key: \d+\./,
      `Current Compatibility Key: ${currentCompatibilityKey}.`
    )
);
