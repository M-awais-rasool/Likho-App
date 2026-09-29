// Imports the prototype's level data (prototype_data.js = window.LIKHO from
// design/prototype/Likho-Prototype.html) into the content folder, one file per
// world and per level (see backend/content/README.md):
//
//   node backend/tools/prototype-import/import.js
//
// It replaces content/courses/english-handwriting/ completely. Once the course
// is edited by hand, edit the JSON files instead of re-running this.
const fs = require('fs');
const path = require('path');
global.window = {};
eval(fs.readFileSync(path.join(__dirname, 'prototype_data.js'), 'utf8'));
const { WORLDS, GUIDES, LEVELS } = window.LIKHO;

const themeIds = ['letterLand', 'smallLetterCove', 'phonicsForest', 'wordTown', 'sentenceSky', 'storySpace'];
const bossIds = ['snail', 'fish', 'bear', 'robotBus', 'cloud', 'moon'];
const paintNames = { '#F2735B': 'red', '#4D9DE0': 'blue', '#FFC83D': 'yellow', '#3BB273': 'green', '#9B7FE6': 'purple' };
const pad2 = n => String(n).padStart(2, '0');
const pic = key => (key ? { key: key.replace(/\s+/g, '_'), label: key, url: null } : null);

const worlds = WORLDS.map((w, i) => ({
  id: `world-${i + 1}`,
  order: i + 1,
  name: w.name,
  skill: w.skill,
  icon: w.icon,
  themeId: themeIds[i],
  boss: { id: bossIds[i], name: w.boss },
}));

function round(levelId, r, k, lv) {
  const id = `${levelId}-r${k + 1}`;
  const card = r.card ? { text: r.card.m || null, picture: pic(r.card.pic), listen: !!r.card.ear } : null;
  const base = { id, type: r.t === 'pick' ? 'pick' : r.t, prompt: { text: r.say, audio: null }, card };
  if (r.t === 'pick') {
    const options = r.opts.map((o, j) => {
      const x = typeof o === 'string' ? { l: o } : o;
      return { id: `${id}-o${j + 1}`, label: x.l, picture: pic(x.pic), color: x.color ? paintNames[x.color] : null, hideLabel: !!x.noLabel };
    });
    base.pick = {
      options,
      answer: r.ans === '*' ? { kind: 'any' } : { kind: 'label', value: r.ans },
      shape: r.shape || null,
      layout: r.layout || null,
      count: r.count || null,
      choiceKey: r.key || null,
      fixCapital: !!r.fix,
    };
  } else if (r.t === 'write') {
    base.write = {
      mode: r.mode,
      target: r.g || null,
      guide: r.g && GUIDES[r.g] ? r.g : null,
      word: r.word || null,
      missingIndex: r.miss == null ? null : r.miss,
      sentence: !!r.sentence,
      story: !!r.story,
    };
  } else if (r.t === 'order') {
    base.order = { tiles: r.tiles };
  } else if (r.t === 'speak') {
    base.speak = { expected: null };
  }
  return base;
}

const levels = LEVELS.map((lv, n) => {
  const id = n === 0 ? 'placement' : `level-${pad2(n)}`;
  return {
    id,
    number: n,
    worldId: n === 0 ? null : `world-${Math.floor((n - 1) / 6) + 1}`,
    placement: n === 0,
    name: lv.name,
    skill: lv.skill,
    icon: lv.icon,
    isBoss: !!lv.boss,
    requiresSubscription: n >= 13,
    intro: { text: lv.intro || '', word: lv.introWord || '', picture: pic(lv.introWord) },
    presentation: {
      shape: lv.shape || null,
      slot: lv.slot || null,
      pad: lv.pad || null,
      layout: lv.layout || null,
      stage: lv.stage || null,
    },
    rounds: lv.rounds.map((r, k) => round(id, r, k, lv)),
  };
});

// ---------------------------------------------------------------- write

const COURSE_ID = 'english-handwriting';
const root = path.join(__dirname, '../../content');
const dir = path.join(root, 'courses', COURSE_ID);
const slug = s => s.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
// "$schema" lets editors check each file; the API strips it
const schema = (file, name) => path.relative(path.dirname(file), path.join(root, 'schema', `${name}.schema.json`));
const write = (file, name, data) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ $schema: schema(file, name), ...data }, null, 2) + '\n');
};
const levelFile = ({ worldId, placement, ...level }) => level; // both come from where the file is

fs.rmSync(dir, { recursive: true, force: true });
write(path.join(dir, 'course.json'), 'course', {
  id: COURSE_ID,
  title: 'English Handwriting',
  description: 'Letters, words and sentences for 5 to 8 year olds: from tracing capitals to writing a story.',
  locale: 'en',
  ages: { min: 5, max: 8 },
  status: 'published',
  schemaVersion: 1,
  updatedAt: '2026-09-27T00:00:00Z',
});
write(path.join(dir, 'glyphs.json'), 'glyphs', { glyphs: GUIDES });
write(path.join(dir, 'placement.json'), 'level', levelFile(levels[0]));
for (const w of worlds) {
  const wdir = path.join(dir, 'worlds', `${pad2(w.order)}-${slug(w.name)}`);
  write(path.join(wdir, 'world.json'), 'world', w);
  for (const l of levels.filter(l => l.worldId === w.id)) {
    write(path.join(wdir, 'levels', `${pad2(l.number)}-${slug(l.name)}.json`), 'level', levelFile(l));
  }
}

const rounds = levels.reduce((a, l) => a + l.rounds.length, 0);
const types = {};
levels.forEach(l => l.rounds.forEach(r => (types[r.type] = (types[r.type] || 0) + 1)));
const pics = new Set();
levels.forEach(l => { if (l.intro.picture) pics.add(l.intro.picture.key); l.rounds.forEach(r => { if (r.card && r.card.picture) pics.add(r.card.picture.key); (r.pick ? r.pick.options : []).forEach(o => o.picture && pics.add(o.picture.key)); }); });
console.log(`wrote ${path.relative(process.cwd(), dir)}: ${worlds.length} worlds, ${levels.length} levels, ${rounds} rounds`, types, `${pics.size} picture keys`);
fs.writeFileSync(path.join(__dirname, 'picture_keys.txt'), [...pics].sort().join('\n') + '\n');
