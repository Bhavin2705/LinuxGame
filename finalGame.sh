#!/bin/sh

command -v dialog >/dev/null 2>&1 || { echo "Error: dialog is required but not installed."; exit 1; }

board="         "
player1_name=""
player2_name=""
player1_symbol=""
player2_symbol=""
player=""
symbol=""
log_file="game.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$log_file"
}

exit_game() {
  log "Game exited"
  dialog --clear --title "Exit" --msgbox "Game exited. Thanks for playing!" 10 40
  reset
  exit 0
}

trap exit_game INT

get_board_element() {
  index=$1
  expr substr "$board" $((index + 1)) 1
}

set_board_element() {
  index=$1
  value=$2
  if [ $index -eq 0 ]; then
    board="$value${board#?}"
  else
    before=$(expr substr "$board" 1 $index)
    after=$(expr substr "$board" $((index + 2)) 9)
    board="$before$value$after"
  fi
}

draw_board() {
  temp_board="$1"
  if [ -z "$temp_board" ]; then
    temp_board="$board"
  fi
  display=""
  i=0
  while [ $i -lt 9 ]; do
    cell=$(expr substr "$temp_board" $((i + 1)) 1)
    if [ "$cell" = " " ]; then
      display="$display$((i+1))"
    else
      display="$display$cell"
    fi
    if [ $(( (i + 1) % 3 )) -ne 0 ]; then
      display="$display | "
    elif [ $i -ne 8 ]; then
      display="$display\n---------\n"
    fi
    i=$((i + 1))
  done
  printf "%s\n" "$display"
}

check_move() {
  choice=$1
  if ! expr "$choice" : '^[1-9]$' >/dev/null; then
    return 1
  fi
  pos=$((choice - 1))
  cell=$(get_board_element $pos)
  if [ "$cell" != " " ]; then
    return 1
  fi
  return 0
}

pick_move() {
  display=$(draw_board)
  options=""
  i=0
  while [ $i -lt 9 ]; do
    cell=$(get_board_element $i)
    if [ "$cell" = " " ]; then
      num=$((i + 1))
      options="$options $num \"Cell $num\""
    fi
    i=$((i + 1))
  done
  eval "dialog --clear --nook --nocancel --title \"Tic Tac Toe - $player's turn\" \
    --menu \"Current Board:\n\n$display\n\nPick a cell number:\" 22 60 9 \
    $options 3>&1 1>&2 2>&3"
}

select_cell() {
  while true; do
    choice=$(pick_move)
    if [ $? -ne 0 ]; then
      return 1
    fi
    if check_move "$choice"; then
      pos=$((choice - 1))
      temp_board="$board"
      temp_board=$(printf "%s%s%s" "${temp_board:0:pos}" "$symbol" "${temp_board:pos+1}")
      display=$(draw_board "$temp_board")
      option=$(dialog --clear --nook --nocancel --title "Move Options" \
        --menu "Current Move:\n\n$display\n\nChoose an option:" 22 60 2 \
        "1" "Submit move" \
        "2" "Undo move" 3>&1 1>&2 2>&3)
      if [ $? -ne 0 ]; then
        return 1
      fi
      if [ "$option" = "1" ]; then
        set_board_element $pos "$symbol"
        log "$player placed $symbol at $((pos + 1))"
        return 0
      fi
    fi
  done
}

check_winner() {
  i=0
  while [ $i -lt 9 ]; do
    c1=$(get_board_element $i)
    c2=$(get_board_element $((i + 1)))
    c3=$(get_board_element $((i + 2)))
    if [ "$c1" != " " ] && [ "$c1" = "$c2" ] && [ "$c2" = "$c3" ]; then
      return 0
    fi
    i=$((i + 3))
  done
  i=0
  while [ $i -lt 3 ]; do
    c1=$(get_board_element $i)
    c2=$(get_board_element $((i + 3)))
    c3=$(get_board_element $((i + 6)))
    if [ "$c1" != " " ] && [ "$c1" = "$c2" ] && [ "$c2" = "$c3" ]; then
      return 0
    fi
    i=$((i + 1))
  done
  c1=$(get_board_element 0)
  c2=$(get_board_element 4)
  c3=$(get_board_element 8)
  if [ "$c1" != " " ] && [ "$c1" = "$c2" ] && [ "$c2" = "$c3" ]; then
      return 0
  fi
  c1=$(get_board_element 2)
  c2=$(get_board_element 4)
  c3=$(get_board_element 6)
  if [ "$c1" != " " ] && [ "$c1" = "$c2" ] && [ "$c2" = "$c3" ]; then
      return 0
  fi
  return 1
}

check_full() {
  i=0
  while [ $i -lt 9 ]; do
    cell=$(get_board_element $i)
    if [ "$cell" = " " ]; then
      return 1
    fi
    i=$((i + 1))
  done
  return 0
}

setup_players() {
  player1_name=$(dialog --clear --title "Player Setup" --inputbox "Enter Player 1 name:" 10 40 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit_game
  fi
  if [ -z "$player1_name" ]; then
    player1_name="Player 1"
  fi
  log "Player 1 is $player1_name"
  player2_name=$(dialog --clear --title "Player Setup" --inputbox "Enter Player 2 name:" 10 40 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit_game
  fi
  if [ -z "$player2_name" ]; then
    player2_name="Player 2"
  fi
  log "Player 2 is $player2_name"
  player1_symbol=$(dialog --clear --title "Symbol Choice" --menu "$player1_name, choose your symbol:" 12 40 2 \
    "X" "Symbol X" \
    "O" "Symbol O" 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit_game
  fi
  if [ "$player1_symbol" = "X" ]; then
    player2_symbol="O"
  elif [ "$player1_symbol" = "O" ]; then
    player2_symbol="X"
  else
    dialog --clear --title "Error" --msgbox "Invalid symbol selected." 10 40
    log "Invalid symbol"
    exit_game
  fi
  log "$player1_name has $player1_symbol, $player2_name has $player2_symbol"
  dialog --clear --title "Symbol Assignment" --msgbox "$player1_name is assigned $player1_symbol\n$player2_name is assigned $player2_symbol" 10 40
}

play_game() {
  board="         "
  player=$player1_name
  symbol=$player1_symbol
  log "Game started"
  while true; do
    if select_cell; then
      display=$(draw_board)
      if check_winner; then
        log "$player wins"
        dialog --clear --title "Game Over" --msgbox "$display\n\n$player wins!" 15 50
        break
      fi
      if check_full; then
        log "Draw"
        dialog --clear --title "Game Over" --msgbox "$display\n\nThe game ended in a draw!" 15 50
        break
      fi
      if [ "$player" = "$player1_name" ]; then
        player=$player2_name
        symbol=$player2_symbol
      else
        player=$player1_name
        symbol=$player1_symbol
      fi
    else
      exit_game
    fi
  done
}

main() {
  log "Tic-Tac-Toe started"
  dialog --clear --title "Welcome to Tic-Tac-Toe!" --msgbox \
    "Welcome to the Tic-Tac-Toe Game\n\nMade by Team 4 G3\nSubmitted to Mr. Amitabh Srivastava\n\nRULES:\n1. The game is played between two players.\n2. Players take turns marking the grid.\n3. The player who first forms a horizontal, vertical, or diagonal line of three of their marks wins.\n4. If all cells are filled and no one wins, the game ends in a draw." 15 50
  setup_players
  while true; do
    play_game
    dialog --clear --title "Rematch" --yesno "Would you like to play again?" 15 50
    if [ $? -ne 0 ]; then
      log "Game ended"
      dialog --clear --title "Thanks" --msgbox "Thanks for playing Tic Tac Toe!" 10 40
      tput reset
      clear
      exit 0
    fi
    log "Rematch"
  done
}

main