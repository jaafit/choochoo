import Card from "@mui/material/Card";
import {Typography} from "@mui/material";

const PlayerCard = ({player, highlight, togglePresent}) => {
  return <Card elevation={highlight ? 10 : 3} onClick={togglePresent}>
    <Typography variant='h4'>{player.name}</Typography>
    <Typography variant='h5'>{player.tickets} tickets</Typography>
  </Card>
};

export default PlayerCard;
