// source for electron/three.global.js — the vendored UMD-ish global THREE bundle.
// esbuild bundles this into `var THREE = (...)()` (see tools/build-three.mjs). re-exports the whole
// three core plus the handful of examples/jsm modules the game references as THREE.* globals.
// keep this in sync with the Haxe externs in src/three/Three.hx.
export * from 'three';

// post-processing stack (bloom) used by the 3D street view
export { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
export { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
export { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
export { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
export { GTAOPass } from 'three/examples/jsm/postprocessing/GTAOPass.js';
export { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
export { Pass, FullScreenQuad } from 'three/examples/jsm/postprocessing/Pass.js';

// glb prop loader (street lamps etc); assets baked by `make models`
export { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
