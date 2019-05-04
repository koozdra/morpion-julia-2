struct Move
    x::Int8
    y::Int8
    direction::Int8
    start_offset::Int8
end

function board_index_at(x, y) 
    return (x + 15) * 40 + (y + 15)
end

function is_direction_taken(board, x, y, direction) 
    return board[board_index_at(x, y)] & mask_dir()[direction + 1] != 0
end

function is_empty_at(board, x, y) 
    return board[board_index_at(x, y)] == 0
end

function is_move_valid(board::Array{UInt8,1}, move::Move) 
    (delta_x, delta_y) = direction_offsets()[move.direction + 1]
    num_empty_points = 0
    empty_point = ()

    # println("considering ", move)
  
    for i in 0:4
        combined_offset = i + move.start_offset
        x = move.x + delta_x * combined_offset
        y = move.y + delta_y * combined_offset

        # println " ", x, " ", y, " ", 
        # println("$x $y $(is_direction_taken(board, x, y, move.direction))")

        # the inner points of the line cannot be taken in the direction of the line
        if i > 0 && i < 4 && is_direction_taken(board, x, y, move.direction)
            # m = Move(x, y, move.direction, i)
            # println("Removing: $m")
            # println("dud")
            return false
        end

        #count the number of empty points and record the last one
        if is_empty_at(board, x, y)
            num_empty_points += 1
            empty_point = (x, y)
        end
    end

    # println(num_empty_points)
    return num_empty_points == 1
end

function mask_x()
    return 0b00001
end

function mask_dir()
    return [0b00010, 0b00100, 0b01000, 0b10000]
end

function initial_moves() 
    return [
    Move(3, -1, 3, 0),
    Move(6, -1, 3, 0),
    Move(2, 0, 1, 0),
    Move(7, 0, 1, -4),
    Move(3, 4, 3, -4),
    Move(7, 2, 2, -2),
    Move(6, 4, 3, -4),
    Move(0, 2, 3, 0),
    Move(9, 2, 3, 0),
    Move(-1, 3, 1, 0),
    Move(4, 3, 1, -4),
    Move(0, 7, 3, -4),
    Move(5, 3, 1, 0),
    Move(10, 3, 1, -4),
    Move(9, 7, 3, -4),
    Move(2, 2, 0, -2),
    Move(2, 7, 2, -2),
    Move(3, 5, 3, 0),
    Move(6, 5, 3, 0),
    Move(-1, 6, 1, 0),
    Move(4, 6, 1, -4),
    Move(3, 10, 3, -4),
    Move(5, 6, 1, 0),
    Move(10, 6, 1, -4),
    Move(6, 10, 3, -4),
    Move(2, 9, 1, 0),
    Move(7, 9, 1, -4),
    Move(7, 7, 0, -2)
  ]
end

function direction_offsets()
    return [(1, -1), (1, 0), (1, 1), (0, 1)]
end

function generate_initial_board()
    board = zeros(UInt8, 40 * 40)

    for move in initial_moves()
        (delta_x, delta_y) = direction_offsets()[move.direction + 1]

        for i in 0:4
            combined_offset = i + move.start_offset
            x = move.x + delta_x * combined_offset
            y = move.y + delta_y * combined_offset

            if x != move.x || y != move.y
                board[board_index_at(x, y)] = mask_x()
            end
        end
    end
    board
end

function update_board(board::Array{UInt8,1}, move::Move)
   	(delta_x, delta_y) = direction_offsets()[move.direction + 1]

    for i in 0:4
        combined_offset = i + move.start_offset
        x = move.x + delta_x * combined_offset
        y = move.y + delta_y * combined_offset

        board[board_index_at(x, y)] |= mask_dir()[move.direction + 1]
    end
end

function eval_line(board, start_x, start_y, direction) 
    (delta_x, delta_y) = direction_offsets()[direction + 1]
    num_empty_points = 0
    empty_point = 0

    for offset in 0:4
        x = start_x + delta_x * offset
        y = start_y + delta_y * offset

        if offset > 0 && offset < 4 && is_direction_taken(board, x, y, direction)
            return nothing
        end

        if is_empty_at(board, x, y)
            num_empty_points += 1
            empty_point = (x, y)
        end
    end

    if num_empty_points == 1
        (point_x, point_y) = empty_point
        offs = start_x - point_x
        # println("FOUND $point_x $point_y $direction $offs")
        return Move(point_x, point_y, direction, start_x - point_x)
    end
end

function find_created_moves(board, point_x, point_y) 
    possible_moves = Move[]

    for direction in 0:3
        for offset in -4:0
        
            (delta_x, delta_y) = direction_offsets()[direction + 1]

            x = point_x + delta_x * offset
            y = point_y + delta_y * offset

            possible_move = eval_line(board, x, y, direction)
            if possible_move != nothing
                push!(possible_moves, possible_move)
            end
        end
    end
    possible_moves
end



function print_board(board) 
    for y in -14:24
        for x in -14:24
            c = board[board_index_at(x, y)]
            print("$c ")
        end
        println()
    end
end

function unit(board_template) 
    for i in 1:5000
        board = copy(board_template);
        moves = random_completion(board)
    end
end

function random_completion(board)
    taken_moves = Move[]

    curr_possible_moves = initial_moves();

    while length(curr_possible_moves) > 0
        move = curr_possible_moves[rand(1:end)]
        push!(taken_moves, move)
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        created_moves = find_created_moves(board, move.x, move.y)
        union!(curr_possible_moves, created_moves)
    end

    taken_moves
end


function dna_index(x::Number, y::Number, direction::Number)
   	(x + 15) * 40 * 4 + (y + 15) * 4 + direction
end

function dna_index(move::Move)
   	dna_index(move.start_x, move.start_y, move.direction)
end

function generate_dna(moves)
   	morpion_dna = rand(40 * 40 * 4)
   	i = 0
   	for move in moves
      		morpion_dna[dna_index(move)] = i
      		i += 1
   	end

   	morpion_dna
end

function run() 
    board_template = generate_initial_board()

    for i in 1:10
        @time unit(board_template)
    end
    
  

end

run();