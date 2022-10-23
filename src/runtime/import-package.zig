//! This file is meant as a dependency for the "app" package.
//! It will only re-export all symbols from "root" under the name "microbe"
//! So we have a flattened and simplified dependency tree.

pub usingnamespace @import("root");
