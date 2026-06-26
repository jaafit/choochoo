// Nominator — plain JS + Tailwind/DaisyUI (no React, no build step).
// Only `players` is persisted; presence / chosen / editing are per-session, just
// like the original React component's local state.

const STORAGE_KEY = 'players';

const state = {
  newPlayer: '',
  players: JSON.parse(localStorage.getItem(STORAGE_KEY)) || [],
  chosenPlayer: undefined, // the player object that was nominated
  presentMap: {},          // { [id]: true } for players "at the table"
  editing: undefined,      // id of the player whose edit controls are open
};

function save() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.players));
}

// ---- Actions ---------------------------------------------------------------

function addPlayer() {
  const name = state.newPlayer.trim();
  if (!name) return;
  const highestId = state.players.reduce((id, p) => Math.max(id, p.id), 0);
  state.players.push({ id: highestId + 1, name, tickets: 0 });
  state.newPlayer = '';
  render();
}

function nominate() {
  const present = presentPlayers();
  let tickets = [];
  present.forEach(p => {
    tickets = tickets.concat(Array(p.tickets).fill(p.id));
  });
  if (!tickets.length) return;

  const chosen = tickets[Math.floor(Math.random() * tickets.length)];

  // Winning costs `present.length` tickets (floored at 0).
  state.players = state.players.map(p =>
    p.id === chosen
      ? { ...p, tickets: Math.max(0, p.tickets - present.length) }
      : p
  );
  state.chosenPlayer = state.players.find(p => p.id === chosen);
  render();
}

function togglePresent(id) {
  if (state.chosenPlayer) return; // locked once someone is nominated
  const wasPresent = state.presentMap[id];
  state.players = state.players.map(p =>
    p.id !== id ? p : { ...p, tickets: p.tickets + (wasPresent ? -1 : 1) }
  );
  state.presentMap = { ...state.presentMap, [id]: !wasPresent };
  render();
}

function addTicket(id, amt) {
  state.players = state.players.map(p =>
    p.id === id ? { ...p, tickets: Math.max(0, p.tickets + amt) } : p
  );
  render();
}

function reset() {
  state.presentMap = {};
  state.chosenPlayer = undefined;
  render();
}

function toggleEditing(id) {
  state.editing = state.editing === id ? undefined : id;
  render();
}

function deletePlayer(id) {
  if (!window.confirm('delete?')) return;
  state.players = state.players.filter(p => p.id !== id);
  state.editing = undefined;
  state.presentMap = { ...state.presentMap, [id]: false };
  render();
}

// ---- Derived ---------------------------------------------------------------

function sortedPlayers() {
  return [...state.players].sort((a, b) => b.tickets - a.tickets);
}
function presentPlayers() {
  return sortedPlayers().filter(p => state.presentMap[p.id]);
}
function absentPlayers() {
  return sortedPlayers().filter(p => !state.presentMap[p.id]);
}

// ---- View ------------------------------------------------------------------

function esc(str) {
  return String(str).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function playerCard(player, { highlight = false } = {}) {
  const shadow = highlight ? 'shadow-2xl ring-2 ring-primary' : 'shadow-md';
  return `
    <div class="card bg-base-100 ${shadow} cursor-pointer transition-shadow hover:shadow-lg"
         data-action="toggle-present" data-id="${player.id}">
      <div class="card-body items-center text-center p-4">
        <h4 class="text-2xl font-semibold">${esc(player.name)}</h4>
        <h5 class="text-xl opacity-70">${player.tickets} tickets</h5>
      </div>
    </div>`;
}

function render() {
  save();

  const present = presentPlayers();
  const absent = absentPlayers();
  const chosen = state.chosenPlayer;

  // The Table
  const tableCards = present
    .map(p => `<div>${playerCard(p, { highlight: p.id === chosen?.id })}</div>`)
    .join('');

  const nominateBtn =
    !chosen && present.length
      ? `<button class="btn btn-outline btn-lg" data-action="nominate">Nominate</button>`
      : '';

  const chosenRow = chosen
    ? `<div class="flex flex-wrap items-center justify-between gap-3 mt-2">
         <h4 class="text-3xl font-semibold">${esc(chosen.name)} nominates</h4>
         <button class="btn" data-action="reset">Reset</button>
       </div>`
    : '';

  // Absent players (with optional edit controls)
  const absentCards = absent
    .map(p => {
      const editing = state.editing === p.id;
      const editTools = editing
        ? `<button class="btn btn-circle btn-sm" data-action="add-ticket" data-id="${p.id}" data-amt="1" title="Add ticket">+</button>
           <button class="btn btn-circle btn-sm" data-action="add-ticket" data-id="${p.id}" data-amt="-1" title="Remove ticket">&minus;</button>
           <button class="btn btn-circle btn-sm btn-error mx-3" data-action="delete" data-id="${p.id}" title="Delete player">&#128465;</button>
           <span class="text-sm opacity-60">id=${p.id}</span>`
        : '';
      return `
        <div class="space-y-2">
          ${playerCard(p)}
          <div class="flex items-center gap-2 px-1">
            <button class="btn btn-circle btn-sm btn-ghost" data-action="edit" data-id="${p.id}" title="Edit">&#9998;</button>
            ${editTools}
          </div>
        </div>`;
    })
    .join('');

  document.getElementById('app').innerHTML = `
    <section class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="text-5xl font-bold text-center mb-4">The Table</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          ${tableCards}
        </div>
        <div class="mt-4">${nominateBtn}</div>
        ${chosenRow}
      </div>
    </section>

    <section class="my-12">
      <div class="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        ${absentCards}
      </div>
    </section>

    <section class="flex flex-wrap items-center gap-3">
      <input id="new-player" class="input input-bordered" placeholder="New Player"
             value="${esc(state.newPlayer)}" />
      <button class="btn btn-primary" data-action="add-player">Add Player</button>
    </section>
  `;

  const input = document.getElementById('new-player');
  if (input) {
    input.addEventListener('input', e => { state.newPlayer = e.target.value; });
    input.addEventListener('keyup', e => { if (e.key === 'Enter') addPlayer(); });
  }
}

// ---- Event delegation ------------------------------------------------------

document.getElementById('app').addEventListener('click', e => {
  const el = e.target.closest('[data-action]');
  if (!el) return;
  const id = el.dataset.id ? Number(el.dataset.id) : undefined;
  switch (el.dataset.action) {
    case 'toggle-present': return togglePresent(id);
    case 'nominate':       return nominate();
    case 'reset':          return reset();
    case 'edit':           return toggleEditing(id);
    case 'add-ticket':     return addTicket(id, Number(el.dataset.amt));
    case 'delete':         return deletePlayer(id);
    case 'add-player':     return addPlayer();
  }
});

render();
