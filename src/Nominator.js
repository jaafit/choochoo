import Container from "@mui/material/Container";
import { useState } from "react";

import Grid from "@mui/material/Grid";
import PlayerCard from "./PlayerCard";
import AddIcon from '@mui/icons-material/Add';
import RemoveIcon from '@mui/icons-material/Remove';
import EditIcon from '@mui/icons-material/Edit';
import DeleteForeverIcon from '@mui/icons-material/DeleteForever';
import {Box, Button, Input, Paper, Typography} from "@mui/material";

const Nominator = () => {
  const [newPlayer, setNewPlayer] = useState('');
  const [players, setPlayers] = useState(JSON.parse(localStorage.getItem('players')) || []);
  const [chosenPlayer, setChosenPlayer] = useState();
  localStorage.setItem('players', JSON.stringify(players));

  const [presentMap, setPresentMap] = useState({});
  const [editing, setEditing] = useState();

  const sorted = [...players].sort((a, b) => b.tickets - a.tickets);
  const presentPlayers = sorted.filter((player) => presentMap[player.id]);
  const absentPlayers = sorted.filter((player) => !presentMap[player.id]);
  console.log('pm', presentMap);


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


  function nominate() {
    console.log('nominating');
    let tickets = [];
    presentPlayers.forEach(player => {
      console.log('adding', player);
      tickets = tickets.concat(Array(player.tickets).fill(player.id));
    });
    console.log(tickets);
    if (!tickets.length)
      return;

    const chosen = tickets[Math.floor(Math.random() * tickets.length)];
    console.log('chose', chosen);

    // decrement ticket
    setPlayers(
      players.map(player => {
        if (player.id === chosen)
          return {...player, tickets: Math.max(0, player.tickets - presentPlayers.length)};
        else
          return player;
      }));

    const player = players.find(player => player.id === chosen);
    setChosenPlayer(player);
  }

  function togglePresent (id) {
    return () => {
      if (chosenPlayer)
        return;
      console.log('toggling', id);
      console.log('was present', presentMap[id]);
      setPlayers(oldPlayers => oldPlayers.map(player => {
        return player.id !== id ? player : {...player, tickets: player.tickets + ( presentMap[id] ? -1 : 1)}}));
      setPresentMap(oldPresentPlayers => { return {...oldPresentPlayers, [id]:!oldPresentPlayers[id]}});
    }
  }

  function addTicket(id, amt) {
    return () => {
      console.log('adding ticket');
      setPlayers(oldPlayers => oldPlayers.map(player => {
        const t = Math.max(0, player.tickets + amt);
        return player.id === id ? {...player, tickets: t} : player
      }));
    }
  }

  function reset() {
    console.log('reset');
    setPresentMap({});
    setChosenPlayer(undefined);
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
        setPresentMap({...presentMap, [playerId]: false});
      }
    }
  }

  return <Container>

    <Paper>
      <Typography align="center" variant="h2">The Table</Typography>
      <Grid container spacing={3} padding={3}>
        {presentPlayers.map(player =>
        <Grid item xs={6} key={player.id}>
          <PlayerCard player={player} highlight={player.id === chosenPlayer?.id} togglePresent={togglePresent(player.id)}/>
        </Grid>
      )}
        <Grid item xs={12}>
          {!chosenPlayer && !!presentPlayers.length && <Button onClick={nominate} variant="outlined" size="large">Nominate</Button>}
        </Grid>

        <Grid item xs={6}>
          {chosenPlayer && <Typography variant="h4">{chosenPlayer.name} nominates</Typography>}
        </Grid>
        <Grid item xs={6}>
          {chosenPlayer && <Button onClick={reset}>Reset</Button>}
        </Grid>
      </Grid>

    </Paper>


    <Box my={10}>
      <Grid container spacing={3}>
        {absentPlayers.map(player =>
          <Grid item lg={3} md={4} sm={6} key={player.id}>
            <PlayerCard player={player} present={presentMap[player.id]} togglePresent={togglePresent(player.id)}/>
            <EditIcon fontSize="large" onClick={toggleEditing(player.id)}/>
            {editing === player.id && <AddIcon fontSize="large" onClick={addTicket(player.id, 1)}/>}
            {editing === player.id && <RemoveIcon fontSize="large" onClick={addTicket(player.id, -1)}/>}
            {editing === player.id && <DeleteForeverIcon fontSize="large" sx={{marginX:3}} onClick={deletePlayer(player.id)}/>}
            {editing === player.id && "id="+player.id}
          </Grid>
        )}
      </Grid>
    </Box>


    <Box>
      <Grid container>
        <Grid item xs={6}>
          <Input label="New Player" variant="outlined" value={newPlayer}
             onChange={(e) => setNewPlayer(e.target.value)}
             onKeyUp={onNewPlayerKeyUp}
          />
        </Grid>
        <Grid item xs={6}>
          <Button onClick={addPlayer}>Add Player</Button>
        </Grid>
      </Grid>
    </Box>
  </Container>;
};

export default Nominator;
