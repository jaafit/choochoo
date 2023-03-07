import classnames from "classnames";

const PlayerCard = ({player, highlight, diminish, togglePresent}) => {
  return <div className={ classnames(
                "cursor-pointer p-4 m-3 text-lg bg-white",
                highlight ? "shadow-2xl" : "shadow",
                {'font-light italic': diminish},
                )}
              onClick={togglePresent}>
    <p>{player.name}</p>
    <p>{player.tickets} tickets</p>
  </div>
};

export default PlayerCard;
