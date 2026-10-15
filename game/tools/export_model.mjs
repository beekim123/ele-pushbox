// Execute the unchanged workbench design model independently of game code.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

export function buildModelRoutes(repoRoot) {
  const modelPath = path.join(repoRoot, 'workbench/js/core/tilemodel.js');
  const context = vm.createContext({});
  vm.runInContext(fs.readFileSync(modelPath, 'utf8'), context, { filename: modelPath });
  const model = context.PB.tilemodel;
  const manifest = JSON.parse(fs.readFileSync(path.join(repoRoot, 'content/export/content-manifest.json'), 'utf8'));
  const output = {};
  for (const group of manifest.groups.filter(g => g.id === 'basics' && g.mode === 'lab')) {
    for (const entry of group.levels) {
      const bytes = fs.readFileSync(path.join(repoRoot, entry.spec));
      const digest = crypto.createHash('sha256').update(bytes).digest('hex');
      if (digest !== entry.sha256) throw new Error('Specification hash mismatch: ' + entry.id);
      const spec = JSON.parse(bytes);
      const replay = model.replay(spec, spec.solution);
      if (replay.failedAt !== undefined || !replay.won) throw new Error('Model solution failed: ' + entry.id);
      output['level:' + entry.id] = replay.steps.map(step => ({
        w: replay.level.w, h: replay.level.h,
        player: { ...step.state.player }, crates: step.state.crates.map(c => ({ ...c })),
        terrain: Array.from(step.state.terrain), bag: { ...step.state.bag },
        doors: step.state.open.map(Boolean), moves: step.state.moves,
        won: model.won(replay.level, step.state),
      }));
    }
  }
  return output;
}

// Optional bounded design-model search. It does not verify any SDK behavior.
export function findM06Alternative(repoRoot, maxStates = 20000) {
  const modelPath = path.join(repoRoot, 'workbench/js/core/tilemodel.js');
  const context = vm.createContext({});
  vm.runInContext(fs.readFileSync(modelPath, 'utf8'), context, { filename: modelPath });
  const model = context.PB.tilemodel;
  const spec = JSON.parse(fs.readFileSync(path.join(repoRoot, 'content/levels/lab/basics/M06.json'), 'utf8'));
  const { level, state } = model.parse(spec);
  const stateKey = s => JSON.stringify([s.player, s.crates, Array.from(s.terrain), s.bag, s.open, s.dev, s.held, s.warped]);
  const queue = [{ state, parent: -1, action: null }];
  const seen = new Set([stateKey(state)]);
  let head = 0;
  let found = -1;
  while (head < queue.length && queue.length <= maxStates) {
    const index = head++;
    const s = queue[index].state;
    const sandOnPlate = s.terrain[5 * level.w + 5] === model.T.SAND;
    const crateAsStep = s.crates.some(c => c.x === 10 && c.y === 4);
    if (model.won(level, s) && sandOnPlate && crateAsStep) {
      found = index;
      break;
    }
    for (const action of model.ACTIONS) {
      const next = model.clone(s);
      if (!model.act(level, next, action).ok) continue;
      const key = stateKey(next);
      if (seen.has(key)) continue;
      seen.add(key);
      queue.push({ state: next, parent: index, action });
    }
  }
  const solution = [];
  for (let index = found; index > 0; index = queue[index].parent) solution.push(queue[index].action);
  solution.reverse();
  return {
    format: 'portitor.design-search/1', id: 'M06', runtime: 'design-model-only',
    found: found >= 0, complete: found >= 0 || head >= queue.length,
    explored: head, queued: queue.length, state_limit: maxStates,
    target: { sand_plate: [5, 5], crate_step: [10, 4], all_goals_lit: true },
    solution,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  const alternative = process.argv[2] === '--m06-alternative';
  const data = alternative ? findM06Alternative(repo) : { format: 'portitor.design-expectations/1', routes: buildModelRoutes(repo) };
  const argumentPath = alternative ? process.argv[3] : process.argv[2];
  const destination = argumentPath ? path.resolve(argumentPath) : path.join(repo, alternative ? 'game/tests/levels/M06-alternative.generated.json' : 'game/tests/levels/model_expected.json');
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, JSON.stringify(data, null, 2) + '\n');
  process.stdout.write(JSON.stringify(alternative ? data : { exported: Object.keys(data.routes).length, destination }) + '\n');
}
