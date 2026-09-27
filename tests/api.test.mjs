import { test } from 'node:test';
import assert from 'node:assert/strict';

let moduleId = 0;
async function setup() {
  const listeners = new Map();
  const configurations = [];
  globalThis.window = {
    __TAURI_INTERNALS__: {
      transformCallback: () => 1,
      invoke: async (command, args) => {
        if (command.endsWith('|register_listener')) listeners.set(args.event, args.handler);
        if (command.endsWith('|set_menu_items')) configurations.push(args.payload);
      },
    },
  };
  const api = await import(`../dist-js/index.js?test=${++moduleId}`);
  return { api, configurations, emit: (event, data) => listeners.get(event).onmessage(data) };
}

test('reconfiguring during a drag keeps cached action IDs and uses current callbacks', async () => {
  const { api, configurations, emit } = await setup();
  const clicks = [];
  await api.setMenuItems({ items: [{ label: 'Quote', onClick: () => clicks.push('old') }] });
  const cachedId = configurations[0].items[0].id;
  for (let i = 0; i < 10; i++) {
    await api.setMenuItems({ items: [{ label: 'Quote', onClick: ({ text }) => clicks.push(text) }] });
  }
  assert.ok(configurations.every(c => c.items[0].id === cachedId));
  emit('click', { id: cachedId, text: 'adjusted selection' });
  emit('dismiss');
  // UIKit may still show a menu built before a (spurious) dismiss.
  emit('click', { id: cachedId, text: 'after dismiss' });
  assert.deepEqual(clicks, ['adjusted selection', 'after dismiss']);
});

test('generated IDs survive an autoClear dismissal', async () => {
  const { api, configurations, emit } = await setup();
  const items = [{ label: 'Quote', onClick: () => {} }];
  await api.setMenuItems({ items });
  emit('dismiss');
  await api.setMenuItems({ items });
  assert.equal(configurations[1].items[0].id, configurations[0].items[0].id);
});

test('duplicate labels remain distinct and explicit IDs are preserved', async () => {
  const { api, configurations } = await setup();
  const items = [{ label: 'Quote' }, { label: 'Quote' }, { label: 'Ask', id: 'ask' }];
  await api.setMenuItems({ items });
  await api.setMenuItems({ items });
  const ids = configurations[0].items.map(i => i.id);
  assert.equal(new Set(ids).size, 3);
  assert.equal(ids[2], 'ask');
  assert.deepEqual(configurations[1].items.map(i => i.id), ids);
});

test('autoClear false preserves callbacks across dismissals', async () => {
  const { api, configurations, emit } = await setup();
  let clicks = 0;
  await api.setMenuItems({ items: [{ label: 'Quote', onClick: () => clicks++ }], autoClear: false });
  const id = configurations[0].items[0].id;
  emit('click', { id, text: '' });
  emit('dismiss');
  emit('click', { id, text: '' });
  assert.equal(clicks, 2);
  await api.clearMenuItems();
  emit('click', { id, text: '' });
  assert.equal(clicks, 2);
});
