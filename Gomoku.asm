.data
board: .space 900 # 15x15 board (225 cells, 4 bytes each)
input_p1: .asciiz "Player 1, please input your coordinates (x,y): "
input_p2: .asciiz "Player 2, please input your coordinates (x,y): "
input_err: .asciiz "Invalid input! x and y must be between 0 and 14. Syntax: x,y.\n"
input_dup: .asciiz "Invalid input! Coordinates already occupied.\n"
win_p1: .asciiz "Player 1 wins!\n"
win_p2: .asciiz "Player 2 wins!\n"
tie: .asciiz "Tie!\n"
x_move: .asciiz "X  "
o_move: .asciiz "O  "
move_count: .word 0
dot: .asciiz ".  "
move_buffer: .space 20
num_buffer: .space 4
write_buffer: .space 2048
result_file: .asciiz "result.txt"
file_err: .asciiz "Error: Cannot open file!\n"
rule: .asciiz "\n======= CARO GAME RULES =======\n\n1. Players take turns placing X and O on a 15x15 board.\n2. Player 1 uses X, Player 2 uses O.\n3. First player to get 5 in a row (horizontal, vertical, or diagonal) wins.\n4. Enter coordinates as x,y (both between 0-14).\n\tFor numbers 0-9, use one digit (e.g., 4) or two digits with a leading zero (e.g., 04).\n\tFor numbers 10-14, use exactly two digits (e.g., 14).\n\tExamples: 4,5 (row 4, column 5), 04,05 (row 4, column 5), 14,09 (row 14, column 9).\n5. The game ends in a tie if the board is filled.\n\n================================\n\n"

.text
main:
#=====================Display Rules=====================
    li $v0, 4 # print string with null terminator
    la $a0, rule
    syscall

#=====================Initalize Board=====================
    # Initialize board with 0s
    la $t0, board
    li $t1, 225 # 225 cells

board_init:
    sw $zero, 0($t0) # set each cell to 0
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bne $t1, $zero, board_init 
    jal board_display # display board
    j init_input # start game

#=====================Display Board=====================
board_display:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    la $s0, write_buffer
    li $t0, 2048

clear_write_buffer:
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $t0, $t0, -1
    bne $t0, $zero, clear_write_buffer
    la $s0, write_buffer

#=====================Display Column=====================
    # Header: 3 " "
    li $t0, 32 # ascii for space
    sb $t0, 0($s0) # a char costs 1 byte
    sb $t0, 1($s0)
    sb $t0, 2($s0)
    addi $s0, $s0, 3

    # Column header: 0-14
    li $t0, 0 # number of columns
col_loop:
    # One digit
    la $t1, num_buffer
    li $t2, 10
    blt $t0, $t2, one_digit
    # Two digits
    li $t2, 49 # ascii for 1
    sb $t2, 0($t1)
    sub $t2, $t0, 10
    addi $t2, $t2, 48 # convert to ascii: num - 10 + '0'
    sb $t2, 1($t1)
    j num_write

one_digit:
    li $t2, 48 # ascii for 0
    sb $t2, 0($t1) # store to num_buffer
    addi $t2, $t0, 48 # convert to ascii: num + '0'
    sb $t2, 1($t1)

num_write:
    li $t2, 32 # ascii for space
    sb $t2, 2($t1)
    # Store to write_buffer
    lb $t2, 0($t1)
    sb $t2, 0($s0)
    lb $t2, 1($t1)
    sb $t2, 1($s0)
    lb $t2, 2($t1)
    sb $t2, 2($s0)
    addi $s0, $s0, 3 # move to next char in write_buffer
    addi $t0, $t0, 1 # move to next column
    li $t2, 15
    bne $t0, $t2, col_loop

    # Next row
    li $t2, 10 # ascii for new line
    sb $t2, 0($s0)
    addi $s0, $s0, 1

#=====================Display Row=====================
    # Row header: 0-14
    li $t0, 0 # number of rows
row_loop:
    # One digit
    la $t1, num_buffer
    li $t2, 10
    blt $t0, $t2, row_one_digit
    # Two digits
    li $t2, 49 # ascii for 1
    sb $t2, 0($t1)
    sub $t2, $t0, 10
    addi $t2, $t2, 48 # convert to ascii: num - 10 + '0'
    sb $t2, 1($t1)
    j row_num_write

row_one_digit:
    li $t2, 48 # ascii for 0
    sb $t2, 0($t1) # store to num_buffer
    addi $t2, $t0, 48 # convert to ascii: num + '0'
    sb $t2, 1($t1)

row_num_write:
    li $t2, 32 # ascii for space
    sb $t2, 2($t1)
    # Store to write_buffer
    lb $t2, 0($t1)
    sb $t2, 0($s0)
    lb $t2, 1($t1)
    sb $t2, 1($s0)
    lb $t2, 2($t1)
    sb $t2, 2($s0)
    addi $s0, $s0, 3 # move to next char in write_buffer

    # Cell: 0-14
    li $t2, 0 # cell index
cell_loop:
    mul $t3, $t0, 15 # move to row: row * 15
    add $t3, $t3, $t2 # move to column of that row: row * 15 + col
    sll $t3, $t3, 2 # multiply by 4 (size of int)
    la $t4, board
    add $t4, $t4, $t3 # get address of cell
    lw $t5, 0($t4) # load cell value
    beq $t5, $zero, cell_dot
    li $t6, 1
    beq $t5, $t6, cell_x
    la $t7, o_move
    j cell_write

cell_dot:
    la $t7, dot
    j cell_write

cell_x:
    la $t7, x_move

cell_write:
    # Store to write_buffer
    lb $t3, 0($t7) 
    sb $t3, 0($s0)
    lb $t3, 1($t7)
    sb $t3, 1($s0)
    lb $t3, 2($t7)
    sb $t3, 2($s0)
    addi $s0, $s0, 3 # move to next char in write_buffer
    addi $t2, $t2, 1 # row's next cell
    li $t3, 15
    bne $t2, $t3, cell_loop

    # Next row
    li $t3, 10 # ascii for new line
    sb $t3, 0($s0)
    addi $s0, $s0, 1
    addi $t0, $t0, 1 # next row
    li $t3, 15
    bne $t0, $t3, row_loop
    sb $zero, 0($s0) # row loop done, add null terminator to write_buffer

    # Print to terminal
    li $v0, 4
    la $a0, write_buffer
    syscall
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

#=====================Check Input=====================
init_input:
    li $s1, 1 # player 1 
game_loop:
    move $a0, $s1
    # Print player prompt
    li $v0, 4 # print string with null terminator
    li $t0, 1 # player 1
    beq $a0, $t0, print_p1
    # Print player 2
    la $a0, input_p2
    syscall
    j get_input

print_p1:
    la $a0, input_p1
    syscall

get_input:
    # Get input from player
    la $t0, move_buffer
    li $t1, 20

clear_move_buffer:
    sb $zero, 0($t0)
    addi $t0, $t0, 1
    addi $t1, $t1, -1
    bne $t1, $zero, clear_move_buffer

    li $v0, 8 # fget string
    la $a0, move_buffer # buffer to store input
    li $a1, 20 # max length
    syscall

    li $t0, 0 # comma flag
    la $t1, move_buffer
    li $t2, 0 # x
    li $t3, 0 # y
    li $t5, 0 # x digit count
    li $t6, 0 # y digit count
    li $t7, -1 # first x digit (invalid initially)
    li $t8, -1 # first y digit (invalid initially)

input_loop:
    lb $t4, 0($t1)
    beq $t4, $zero, input_check # ascii for null terminator
    beq $t4, 10, input_check # ascii for new line
    beq $t4, 44, input_comma # ascii for comma
    blt $t4, 48, input_error # less than '0'
    bgt $t4, 57, input_error # greater than '9'
    sub $t4, $t4, 48 # convert to int: num - '0'
    beq $t0, $zero, input_x
    beq $t0, 1, input_y # comma found, check input y

input_x:
    beq $t5, $zero, set_first_x # store first x digit
    bgt $t5, 1, input_error # more than 2 digits

store_x:
    mul $t2, $t2, 10 # x *= 10
    add $t2, $t2, $t4 # x += num
    addi $t5, $t5, 1 # increment x digit count
    j next_char

set_first_x:
    move $t7, $t4 # store first x digit
    j store_x

input_y:
    beq $t6, $zero, set_first_y # store first y digit
    bgt $t6, 1, input_error # more than 2 digits

store_y:
    mul $t3, $t3, 10 # y *= 10
    add $t3, $t3, $t4 # y += num
    addi $t6, $t6, 1 # increment y digit count
    j next_char

set_first_y:
    move $t8, $t4 # store first y digit
    j store_y

input_comma:
    bne $t0, $zero, input_error # more than 1 comma
    li $t0, 1 # comma found

next_char:
    addi $t1, $t1, 1 # next char
    j input_loop 
 
input_error:
    li $v0, 4 # print string with null terminator
    la $a0, input_err
    syscall
    j game_loop

input_check:
    # Check conditions
    bne $t0, 1, input_error # no comma found
    beq $t5, $zero, input_error # no x digits
    blt $t2, 0, input_error # x < 0
    bgt $t2, 14, input_error # x > 14
    blt $t3, 0, input_error # y < 0
    bgt $t3, 14, input_error # y > 14
    # Check x format
    li $t9, 10
    blt $t2, $t9, check_x_single # x < 10
    bne $t5, 2, input_error # if x >= 10, must have 2 digits
    beq $t7, $zero, input_error # if x >= 10, first digit != 0
    j check_y

check_x_single:
    bgt $t5, 2, input_error # if x < 10, max 2 digits
    j check_y

check_y:
    # Check y format
    blt $t3, $t9, check_y_single # y < 10
    bne $t6, 2, input_error # if y >= 10, must have 2 digits
    beq $t8, $zero, input_error # if y >= 10, first digit != 0
    j check_coords

check_y_single:
    bgt $t6, 2, input_error # if y < 10, max 2 digits
    j check_coords

check_coords:
    mul $t0, $t2, 15 # move to row: x * 15
    add $t0, $t0, $t3 # move to col of that row: x * 15 + y
    sll $t0, $t0, 2 # multiply by 4 (size of int)
    la $t1, board
    add $t1, $t1, $t0 # get address of cell
    lw $t0, 0($t1) # load cell value
    beq $t0, $zero, input_valid # cell is empty
    
input_invalid:
    li $v0, 4 # print string with null terminator
    la $a0, input_dup
    syscall
    j game_loop

input_valid:
    sw $s1, 0($t1) # store player number to cell
    lw $t0, move_count # load move count
    addi $t0, $t0, 1 # increase move count
    sw $t0, move_count # store move count
    move $s2, $t2 # x
    move $s3, $t3 # y
    jal board_display # display board
    j set_dir

#=====================Check Win=====================
set_dir:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)

    # Check horizontal
    li $t0, 0
    jal check_dir
    bne $v0, $zero, set_win

    # Check vertical
    li $t0, 1 
    jal check_dir
    bne $v0, $zero, set_win

    # Check diagonal
    li $t0, 2
    jal check_dir
    bne $v0, $zero, set_win

    # Check anti-diagonal
    li $t0, 3 
    jal check_dir
    bne $v0, $zero, set_win

    # No win found, check for tie
    lw $t0, move_count # load move count
    li $t1, 225 # max moves
    beq $t0, $t1, set_tie # check if tie

    # Switch players
    li $t0, 1
    beq $t0, $s1, set_p2 # if player 1, switch to player 2
    li $s1, 1 # if player 2, switch to player 1
    j game_loop

set_p2:
    li $s1, 2 # set player 2
    j game_loop

set_win:
    move $t0, $s1 # set $t0 to player ID (1 or 2)
    j result_found

set_tie:
    li $t0, 0 # set $t0 to 0 for tie
    j result_found

#=====================Check Direction=====================
check_dir:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $t1, 1 # counter
    move $t2, $s2
    move $t3, $s3
    beq $t0, $zero, check_hor
    li $t9, 1 # vertical
    beq $t0, $t9, check_ver
    li $t9, 2 # diagonal
    beq $t0, $t9, check_diag
    li $t9, 3 # anti-diagonal
    beq $t0, $t9, check_anti_diag

check_hor: 
    li $t4, 0
    li $t5, 1
    j check_pos

check_ver:
    li $t4, 1
    li $t5, 0
    j check_pos

check_diag:
    li $t4, 1
    li $t5, 1
    j check_pos

check_anti_diag:
    li $t4, -1
    li $t5, 1
    j check_pos

check_pos:
    move $t6, $s2 # x
    move $t7, $s3 # y

pos_loop:
    add $t6, $t6, $t4 # x + offset
    add $t7, $t7, $t5 # y + offset
    # Check conditions
    blt $t6, $zero, check_neg # x < 0
    bgt $t6, 14, check_neg # x > 14
    blt $t7, $zero, check_neg # y < 0
    bgt $t7, 14, check_neg # y > 14
    # Check cell value
    mul $t8, $t6, 15 # move to row: x * 15
    add $t8, $t8, $t7 # move to col of that row: x * 15 + y
    sll $t8, $t8, 2 # multiply by 4 (size of int)
    la $t9, board
    add $t9, $t9, $t8 # get address of cell
    lw $t8, 0($t9) # load cell value
    bne $t8, $s1, check_neg # check if cell value if of player
    addi $t1, $t1, 1 # increase counter
    li $t8, 5 # check if counter is 5
    beq $t1, $t8, win_found
    j pos_loop

check_neg:
    move $t6, $s2 # x
    move $t7, $s3 # y

neg_loop:
    sub $t6, $t6, $t4 # x - offset
    sub $t7, $t7, $t5 # y - offset
    # Check conditions
    blt $t6, $zero, check_end
    bgt $t6, 14, check_end
    blt $t7, $zero, check_end
    bgt $t7, 14, check_end
    # Check cell value
    mul $t8, $t6, 15 # move to row: x * 15
    add $t8, $t8, $t7 # move to col of that row: x * 15 + y
    sll $t8, $t8, 2 # multiply by 4 (size of int)
    la $t9, board
    add $t9, $t9, $t8 # get address of cell
    lw $t8, 0($t9) # load cell value
    bne $t8, $s1, check_end # check if cell value is of player
    addi $t1, $t1, 1 # increase counter
    li $t8, 5 # check if counter is 5
    beq $t1, $t8, win_found
    j neg_loop

check_end:
    li $v0, 0
    j end_dir

win_found:
    li $v0, 1 # return 1 if win found
    j end_dir

end_dir:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

#=====================Result Found=====================
result_found:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    la $s0, write_buffer
find_buffer_end:
    lb $t1, 0($s0)
    beq $t1, $zero, buffer_end
    addi $s0, $s0, 1
    j find_buffer_end

buffer_end:
    # Tie found
    beq $t0, $zero, write_tie
    # Player 1 wins
    li $t2, 1
    beq $t0, $t2, write_p1
    # Player 2 wins
    la $t3, win_p2 
    move $t0, $t3
    j write_result

write_tie:
    la $t3, tie 
    move $t0, $t3
    j write_result

write_p1:
    la $t3, win_p1 
    move $t0, $t3
    j write_result

write_result:
    lb $t2, 0($t0)
    beq $t2, $zero, result_end
    sb $t2, 0($s0)
    addi $s0, $s0, 1
    addi $t0, $t0, 1
    j write_result

result_end:
    sb $zero, 0($s0) # ascii for null terminator
    # Open file
    li $v0, 13 # open file
    la $a0, result_file # file name
    li $a1, 1 # write mode
    syscall
    move $a0, $v0 # file descriptor
    bltz $a0, file_error # check if file opened successfully

    # Write to file
    la $t0, write_buffer 
    sub $t1, $s0, $t0 # length of string = end - start
    li $v0, 15 # write to file
    la $a1, write_buffer # buffer to write
    move $a2, $t1 # length of string
    syscall

    # Close file
    li $v0, 16 # close file
    syscall

    # Print result to terminal
    li $v0, 4 # print string with null terminator
    move $a0, $t3 # result: win_p1, win_p2 or tie
    syscall

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    j exit

file_error:
    li $v0, 4 # print string with null terminator
    la $a0, file_err
    syscall

exit:
    li $v0, 10 # exit
    syscall
