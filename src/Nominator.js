import { useState } from "react";
import PlayerCard from "./PlayerCard";

const Nominator = () => {
  const [newPlayer, setNewPlayer] = useState('');
  const [players, setPlayers] = useState(JSON.parse(localStorage.getItem('players')) || []);
  const [chooser, setChooser] = useState();
  localStorage.setItem('players', JSON.stringify(players));

  const [editing, setEditing] = useState();

  const s = (a, b) => (a.name < b.name) ?  -1 : ( a.name > b.name) ? 1 : 0;
  const sorted = [...players].sort(s);
  const presentPlayers = sorted.filter(p => ['waiting', 'playing'].includes(p.status));
  const waitingPlayers = sorted.filter(p => p.status==='waiting');
  const absentPlayers = sorted.filter(p => !p.status );

  function onNewPlayerKeyUp(e) {
    if (e.key === 'Enter')
      addPlayer();
  }

  function addPlayer() {
    const highestId = players.reduce((id, player) => Math.max(id, player.id), 0);
    console.log('adding player id', highestId+1);
    setPlayers(oldPlayers =>
       [...oldPlayers, { id:highestId+1, name: newPlayer, tickets: 0 }]
    );
    setNewPlayer('');
  }


  function choose() {
    console.log('choosing');
    let tickets = [];
    waitingPlayers.forEach(player => {
      console.log('adding', player);
      if (player.tickets > 0)
        tickets = tickets.concat(Array(player.tickets).fill(player.id));
    });
    console.log(tickets);
    if (!tickets.length)
      return;

    const chooserId = tickets[Math.floor(Math.random() * tickets.length)];
    console.log('chose', chooserId);

    setPlayers(
      players.map(p => ({
            ...p,
            status: p.status === 'playing' ? undefined : p.id === chooserId ? 'playing' : p.status,
            tickets: p.tickets -
              (p.id === chooserId ? 1 : 0),
          }))
    );

    const player = players.find(player => player.id === chooserId);
    setChooser(player);
  }

  function togglePresent (player) {
    return () => {
      console.log('toggling', player);
      if (chooser) {
        const t = player.status === 'playing' ? 1 : -1;
        setPlayers(oldPlayers => oldPlayers.map(p =>
            ({...p,
              status: p.id === player.id ?
                  (p.status === 'playing' ? 'waiting' : p.status === 'waiting' ?  'playing' : p.status) :
                  p.status,
              tickets: p.tickets + (p.id === chooser.id ?  t : 0),
            })));
      }
      else {
        const t = player.status === 'waiting' ? -1 : !player.status ? 1 : 0;
        setPlayers(oldPlayers => oldPlayers.map(p => ({
          ...p,
          status: p.id === player.id ?
              (p.status === 'waiting' ? undefined : !p.status  ? 'waiting' : p.status) :
              p.status,
          tickets: p.tickets + (player.id === p.id ? t : 0),
        })));
      }
    }
  }

  function addTicket(id, amt) {
    return () => {
      console.log('adding ticket');
      setPlayers(oldPlayers => oldPlayers.map(player => {
        const t = player.tickets + amt;
        return player.id === id ? {...player, tickets: t} : player
      }));
    }
  }

  function reset() {
    console.log('reset');
    setChooser(undefined);
    setPlayers(oldPlayers => oldPlayers.map(player => ({
      ...player,
      status: undefined,
      tickets: Math.max(0, player.tickets)})));
  }

  function toggleEditing(playerId) {
    return () => {
      setEditing(editing === playerId ? undefined : playerId);
    }
  }

  function deletePlayer(playerId) {
    return () => {
      if (window.confirm('delete?')) {
        setPlayers(players.filter(player => player.id !== playerId));
        setEditing(undefined);
      }
    }
  }

  return <div>

    <div className="drop-shadow p-3 m-2 bg-white">
      <p className="text-xl">The Table</p>
      <div className="p-3 flex flex-row flex-wrap">
        {presentPlayers.map(player =>
          <PlayerCard  key={player.id}
                       player={player}
                       highlight={player.id === chooser?.id}
                       diminish={player.status === 'playing'}
                       togglePresent={togglePresent(player)}/>
      )}

        <div className="w-full mt-5 ml-0">
          { players.filter(p => p.status === 'waiting').length >= 2 &&
              <button className="bg-blue-200 p-2 m-3" onClick={choose}>Choose</button>}
        </div>


        {players.every(p => p.status !== 'waiting') && <div className="p-3" >
          {chooser && <button onClick={reset}>Reset</button>}
        </div>}
      </div>

    </div>


    <div className="my-10 flex flex-row flex-wrap">
        {absentPlayers.map(player =>
          <div className="inline-block" key={player.id}>
            <PlayerCard player={player} togglePresent={togglePresent(player)}/>
            <button onClick={toggleEditing(player.id)}>edit</button>

            {editing === player.id &&
                <div className="text-xl flex flex-row space-x-2">
                  <button onClick={addTicket(player.id, 1)}>+</button>
                  <button onClick={addTicket(player.id, -1)}>-</button>
                  <button className="mx-3" onClick={deletePlayer(player.id)}>delete</button>
                  <p>{"id="+player.id}</p>
            </div>}
          </div>
        )}
    </div>


    <div className="flex flex-row space-x-2 p-2">
          <input value={newPlayer}
             onChange={(e) => setNewPlayer(e.target.value)}
             onKeyUp={onNewPlayerKeyUp}
          />
          <button onClick={addPlayer}>Add Player</button>
    </div>
  </div>;
};

export default Nominator;
