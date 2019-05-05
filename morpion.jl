struct Move
    x::Int8
    y::Int8
    direction::Int8
    start_offset::Int8
end

function board_index_at(x, y) 
    return (x + 15) * 40 + (y + 15)
end

function is_direction_taken(board::Array{UInt8,1}, x, y, direction) 
    return board[board_index_at(x, y)] & mask_dir()[direction + 1] != 0
end

function is_empty_at(board::Array{UInt8,1}, x, y) 
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

function eval_line(board::Array{UInt8,1}, start_x, start_y, direction) 
    (delta_x, delta_y) = direction_offsets()[direction + 1]
    num_empty_points = 0
    empty_point = 0
    empty_point_offset = 0

    for offset in 0:4
        x = start_x + delta_x * offset
        y = start_y + delta_y * offset

        if offset > 0 && offset < 4 && is_direction_taken(board, x, y, direction)
            return nothing
        end

        if is_empty_at(board, x, y)
            num_empty_points += 1
            empty_point = (x, y)
            empty_point_offset = offset
        end
    end

    if num_empty_points == 1
        (point_x, point_y) = empty_point
        # println("FOUND $point_x $point_y $direction $offs")
        return Move(point_x, point_y, direction, -empty_point_offset)
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

function unit_dict(iterations, board_template, moves) 
    for i in 1:iterations
        dna = generate_dna_dict(moves);
        eval_moves = eval_dna_dict(copy(board_template), dna)
        if (moves != eval_moves)
            println("oh shit")
        end
    end
end

function unit(iterations, board_template, moves) 
    for i in 1:iterations
        
        dna = generate_dna(moves);
        eval_moves = eval_dna(copy(board_template), dna)
        if (length(moves) != length(eval_moves))
            println("oh shit")
        end
    end
end

function random_completion(board)
    taken_moves = Move[]

    curr_possible_moves = initial_moves();
    i = 1

    while length(curr_possible_moves) > 0
        move = curr_possible_moves[rand(1:end)]
        
        # move = curr_possible_moves[1]
        # println()
        # println("making move ($i): $move ($(is_move_valid(board, move)))")
        # println("possibles $(length(curr_possible_moves)) $curr_possible_moves")
        push!(taken_moves, move)
        update_board(board, move)
        remove_moves = filter((move)->!is_move_valid(board, move), curr_possible_moves)
        # println("remove moves $(length(remove_moves)) $remove_moves")
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        created_moves = find_created_moves(board, move.x, move.y)
        # println("created moves $(length(created_moves)) $created_moves")
        union!(curr_possible_moves, created_moves)
        # println("new possibles $(length(curr_possible_moves)) $curr_possible_moves")
        i += 1
    end

    taken_moves
end


function dna_index(x::Number, y::Number, direction::Number)
   	(x + 15) * 40 * 4 + (y + 15) * 4 + abs(direction)
end

function start_point(move::Move)
    (delta_x, delta_y) = direction_offsets()[move.direction + 1]
    (move.x + (delta_x * move.start_offset), move.y + (delta_y * move.start_offset))
end

function dna_index(move::Move)
    (move_x, move_y) = start_point(move)
   	dna_index(move_x, move_y, move.direction)
end

# dna ideas
#  zeros(Uint8, 40 * 40 * 4) break ties on evaluation
#
#  Dict{Tuple{Int8,Int8},Int8} (try immutable) (size_hint)

function generate_dna(moves)
   	morpion_dna = rand(40 * 40 * 4)
    i = 0
    l = length(moves)
    # println("generating dna:")
   	for move in moves
        morpion_dna[dna_index(move)] = l - i + 1
        # println("$move $(dna_index(move)) $(morpion_dna[dna_index(move)])")
        i += 1
    end

   	morpion_dna
end

function generate_dna_dict(moves::Array{Move})
    morpion_dna = Dict{Int64,Int64}()
    i = 1
    l = length(moves)
    for move in moves
        morpion_dna[dna_index(move)] = l - i + 1
        i += 1
    end
    morpion_dna
end

function eval_dna(board, dna::Array{Float64,1})
   	curr_possible_moves = initial_moves()
    taken_moves = Move[]

    function move_reducer(a, b)
        (dna[dna_index(a)] > dna[dna_index(b)]) ? a : b
    end
    i = 1
     
    while length(curr_possible_moves) > 0
        # println("possible moves:")
        # map(possible_move->println("$possible_move $(dna[dna_index(possible_move)])"), curr_possible_moves)
        move = reduce(move_reducer, curr_possible_moves)
        # println("making move: $move $(dna[dna_index(move)]) $(is_move_valid(board, move)) $(moves[i])")
        push!(taken_moves, move)
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        created_moves = find_created_moves(board, move.x, move.y)
        union!(curr_possible_moves, created_moves)

        i += 1
    end

   	taken_moves
end

function eval_dna_dict(board, dna)
    curr_possible_moves = initial_moves()
    taken_moves = Move[]

    function move_reducer(a, b)
        a_rank = 0
        b_rank = 0
        if haskey(dna, dna_index(a))
            a_rank = dna[dna_index(a)]
        else
            a_rank = -rand(1:1000)
        end

        if haskey(dna, dna_index(b))
            b_rank = dna[dna_index(b)]
        else
            b_rank = -rand(1:1000)
        end
        
        (a_rank > b_rank) ? a : b
    end
  
    while length(curr_possible_moves) > 0
        move = reduce(move_reducer, curr_possible_moves)
        push!(taken_moves, move)
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        created_moves = find_created_moves(board, move.x, move.y)
        union!(curr_possible_moves, created_moves)
    end

    taken_moves
end

function modification_triple(board, moves)
   	morpion_dna = generate_dna(moves)

    #force the three to be different?? 
    # for i = 1:3
    # morpion_dna[dna_index(moves[rand(1:end)])] = -rand()
    morpion_dna[dna_index(moves[rand(1:end)])] = -1
   	# end

   	eval_dna(board, morpion_dna)
end

function run() 
    board_template = generate_initial_board()

    min_accept_delta = 0

    curr_moves = random_completion(copy(board_template))
    step = 0

    # println("done $(length(curr_moves))")
    #TODO: type
    random_completion_moves = random_completion(copy(board_template))
    # hash = hash(random_completion_moves)
    # pool = [random_completion(copy(board_template))]
    # pool_visits = Dict()


    
    while true
        # selection


        eval_moves = modification_triple(copy(board_template), curr_moves)
        curr_score = length(curr_moves)
        eval_score = length(eval_moves)
        eval_hash = hash(eval_moves)
        # println("$step. $score -> $eval_score")
        if (eval_score >= curr_score + min_accept_delta)
            # println("$step. $curr_score -> $eval_score")
            curr_moves = eval_moves
            # pool_visits[hash(curr_moves)] = 1
        end

        if (eval_score > curr_score)
            println("$step. $curr_score -> $eval_score")
            # pool_visits = Dict()
            # pool = []
            
        end

        # if step % 1000 == 0
        #     println("visits: $(length(pool_visits))")
        # end

        step += 1
    end

    # println(hash([initial_moves()]))
    # println(hash([initial_moves()]))

    

    # println("$(length(moves)) -> $(length(mod_moves))")

    # moves = random_completion(copy(board_template))

    # dna = generate_dna(moves);
    # eval_moves = eval_dna(copy(board_template), dna, moves)
    # println()
    # println(moves)
    # println()
    # println(eval_moves)

    # println("$(length(moves)) -> $(length(eval_moves))")

    # curr_possible_moves = initial_moves()
    
    # println()
    # # println(curr_possible_moves)
    # a = map(dna_index, curr_possible_moves);
    # println("a is")
    # println(a)
    # b = map(move->dna[dna_index(move)], curr_possible_moves);
    # println("b is")
    # println(b)
    
    
    
    iterations = 1000
    moves = random_completion(copy(board_template))

    println(start_point(Move(3, 4, 3, -3)))
    println("dict")
    for i in 1:10
        @time unit_dict(iterations, board_template, moves)
    end

    println("float array")
    for i in 1:10
        @time unit(iterations, board_template, moves)
    end
end

run();