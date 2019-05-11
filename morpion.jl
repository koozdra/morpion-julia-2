import Dates
using Random

struct Move
    x::Int8
    y::Int8
    direction::Int8
    start_offset::Int8
end

mutable struct Node
    move::Move
    candidate_possible_moves::Array{Move,1}

    children::Array{Node,1}
    visits::UInt64
    average::Float64
end

# function isless(a::Move, b::Move)
#     (a.x, a.y, a.direction, a.start_offset) < (b.x, b.y, b.direction, b.start_offset)
# end

function build_node(move, candidate_possible_moves)
    Node(move, candidate_possible_moves, [], 0, 0)
end

function maxby(f, arr)
    reduce((a, b)->f(a) > f(b) ? a : b, arr)
end

function board_index_at(x::Number, y::Number) 
    return (x + 15) * 40 + (y + 15)
end

function is_direction_taken(board::Array{UInt8,1}, x::Number, y::Number, direction::Number) 
    return board[board_index_at(x, y)] & mask_dir()[direction + 1] != 0
end

function is_empty_at(board::Array{UInt8,1}, x::Number, y::Number) 
    return board[board_index_at(x, y)] == 0
end

function is_move_valid(board::Array{UInt8,1}, move::Move) 
    (delta_x, delta_y) = direction_offsets()[move.direction + 1]
    num_empty_points = 0
    empty_point = ()

    for i in 0:4
        combined_offset = i + move.start_offset
        x = move.x + delta_x * combined_offset
        y = move.y + delta_y * combined_offset

        # the inner points of the line cannot be taken in the direction of the line
        if i > 0 && i < 4 && is_direction_taken(board, x, y, move.direction)
            return false
        end

        #count the number of empty points and record the last one
        if is_empty_at(board, x, y)
            num_empty_points += 1
            empty_point = (x, y)
        end
    end

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

function eval_line(board::Array{UInt8,1}, start_x::Number, start_y::Number, direction::Number) 
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
        return Move(point_x, point_y, direction, -empty_point_offset)
    end
end

function find_created_moves(board::Array{UInt8,1}, point_x::Number, point_y::Number) 
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

function print_board(board::Array{UInt8,1}) 
    for y in -14:24
        for x in -14:24
            c = board[board_index_at(x, y)]
            print("$c ")
        end
        println()
    end
end


function eval_possible_move_reducer(board, possible_move_reducer)
    curr_possible_moves = initial_moves()
    taken_moves = Move[]

    i = 1
  
    while length(curr_possible_moves) > 0
        move = reduce(possible_move_reducer, curr_possible_moves)
        push!(taken_moves, move)
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        created_moves = find_created_moves(board, move.x, move.y)
        union!(curr_possible_moves, created_moves)

        i += 1
    end

    taken_moves
end

function random_possible_move_reducer(a, b)
    rand(Bool) ? a : b
end

function random_completion(board)
    eval_possible_move_reducer(board, random_possible_move_reducer)
end

function eval_dna(board, dna::Array{Float64,1})
    function dna_move_reducer(a, b)
        (dna[dna_index(a)] > dna[dna_index(b)]) ? a : b
    end

    eval_possible_move_reducer(board, dna_move_reducer)
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

   	for move in moves
        morpion_dna[dna_index(move)] = l - i + 1
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

function eval_dna_dict(board, dna)
    curr_possible_moves = initial_moves()
    taken_moves = Move[]

    function move_reducer(a, b)
        a_rank = 0
        b_rank = 0
        if haskey(dna, dna_index(a))
            a_rank = dna[dna_index(a)]
        else
            a_rank = -rand(1:100)
        end

        if haskey(dna, dna_index(b))
            b_rank = dna[dna_index(b)]
        else
            b_rank = -rand(1:100)
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

function modification_triple(board, moves::Array{Move})
   	morpion_dna = generate_dna(moves)

    for i = 1:rand(1:4)
        morpion_dna[dna_index(moves[rand(1:end)])] = -rand()
   	end

   	eval_dna(board, morpion_dna)
end

function modification_triple_dict(board, moves::Array{Move})
    morpion_dna = generate_dna_dict(moves)

    for i = 1:3
        morpion_dna[dna_index(moves[rand(1:end)])] = -100000
    end

    eval_dna_dict(board, morpion_dna)
end

function points_hash(moves::Array{Move})
   	hash(sort(map((move)->(move.x, move.y), moves)))
end

function unit(board_template, curr_moves)
    for i in 1:1000
        curr_moves_points_hash = points_hash(curr_moves)
        # eval_moves = modification_triple(copy(board_template), curr_moves)
        dna = generate_dna(curr_moves)
        eval_dna(copy(board_template), dna)
    end
end

function find_loose_moves(moves)

end

function random_completion_from_move(board, possible_moves)
    move = reduce(random_possible_move_reducer, possible_moves)

end

function select_node_e_greedy(nodes)
    if rand(Float64) < 0.1
        nodes[rand(1:end)]
    else
        maxby(node->node.average, nodes)
    end
end

function node_ucb_rank(total_visits, highest_average, node)
    rescaled_average = highest_average / node.average

    if total_visits == 0
        return 0
    end

    rescaled_average + sqrt(2 * (log(total_visits) / node.visits))
end

function select_node_ucb(nodes)
    total_visits = sum_node_visits(nodes)
    highest_average_node = maxby(node->node.average, nodes)
    maxby(node->node_ucb_rank(total_visits, highest_average_node.average, node), nodes)
end

function sum_node_visits(nodes)
    # reduce((a, b)->a.visits + b.visits, nodes)
    sum(map(a->a.visits, nodes))
end

function select_node(nodes)
    select_node_e_greedy(nodes)
    # select_node_ucb(nodes)
    # first(nodes)
end

function update_node_average(observation, node)
    node.average = node.average + (observation - node.average) / (node.visits)
end

# possible_moves: the possible moves on the board currently
function visit_node(board, possible_moves, taken_moves, node)

    node.visits += 1

    move = node.move
    push!(taken_moves, move)
    update_board(board, move)
    filter!((move)->is_move_valid(board, move), possible_moves)


    # print("$(node.move)")

    # if there candidate moves, pop one and create a child
    if !isempty(node.candidate_possible_moves)
        curr_possible_moves = possible_moves

        # TODO can this selection be made smarter
        # move = pop!(node.candidate_possible_moves)

        move = node.candidate_possible_moves[rand(1:end)]
        node.candidate_possible_moves = without(move, node.candidate_possible_moves)

        new_node = build_node(move, copy(possible_moves))
        push!(node.children, new_node)

        done = false
        
        # TODO time against recursive implementation

        while !done
            push!(taken_moves, move)
            update_board(board, move)
            filter!((move)->is_move_valid(board, move), curr_possible_moves)
            created_moves = find_created_moves(board, move.x, move.y)
            union!(curr_possible_moves, created_moves)
            if isempty(curr_possible_moves)
                done = true
            else
                move = reduce(random_possible_move_reducer, curr_possible_moves)
            end
        end

        new_node.average = length(taken_moves)

        # println(" fv $(move) -> $(length(taken_moves))")

        return taken_moves
    end

    if isempty(node.children) 
        # println("no chillin with length $(length(taken_moves))")
        return taken_moves
    end

    # all the candidate moves have been evaluated
    # node = select_node()

    # node = select_node(node.children)

    # println("select node for $(node.move)")
    # return visit_node(node)
    moves = visit_node(board, possible_moves, taken_moves, select_node(node.children))

    
    # node.average = node.average + ((length(moves) - node.average) / (node.visits))
    update_node_average(length(moves), node)

    return moves
end

function without(element, arr)
    filter(e->e != element, arr)
end

function possible_moves_after_move(board, possible_moves, move)
    update_board(board, move)
    filter!((move)->is_move_valid(board, move), possible_moves)
end

function log_nodes(nodes)
    for node in nodes
        println("$(node.move) $(node.visits) $(length(node.children)) $(node.average)")
    end
    println()
end

function run() 
    board_template = generate_initial_board()

    # for move in initial_moves()
    #     moves = possible_moves_after_move(copy(board_template), initial_moves(), move)
    #     println("$(move) $(length(moves))")
    # end

    nodes = map(move->build_node(move, initial_moves()), initial_moves())

    # for i in 1:3
    #     node = select_node(nodes)
    #     moves = visit_node(copy(board_template), initial_moves(), [], node)
    #     update_node_average(length(moves), node)
    #     println("visit: $(length(moves))")
    #     log_nodes(nodes)
    # end

    # println(length(moves))
    # moves = initial_moves()
    # println(length(without(moves[1], moves)))
    step = 0
    max_score = 0
    while true
        # for node in nodes
        #     visit_node(copy(board_template), initial_moves(), [], node)
        # end
        # visit_node(select_node(nodes))

        # visit_node(board, possible_moves, taken_moves, node)
        node = select_node(nodes)
        moves = visit_node(copy(board_template), initial_moves(), [], node)
        update_node_average(length(moves), node)

        if length(moves) > max_score
            max_score = length(moves)

            println()
            println("!!!!!")
            println(moves)
            println()
            println("$(step). $(max_score)")
        end

        if step % 10000 == 0
            for node in nodes
                println("$(node.move) $(node.visits) $(length(node.children)) $(node.average)")
            end

            println()
        end
        

        step += 1
    end

    


    # moves_119 = [Move(7, 0, 1, -4), Move(6, 5, 3, 0), Move(2, 2, 0, -2), Move(3, 4, 3, -4), Move(7, 2, 2, -2), Move(5, 6, 1, 0), Move(4, 5, 2, -2), Move(5, 4, 0, -2), Move(4, 3, 2, -1), Move(5, 2, 0, -2), Move(4, 2, 1, -2), Move(4, 6, 1, -3), Move(-1, 3, 1, 0), Move(5, 3, 1, -2), Move(5, 1, 3, -1), Move(6, 4, 3, -3), Move(1, 5, 2, -2), Move(0, 7, 3, -4), Move(3, 5, 3, -1), Move(9, 2, 3, 0), Move(7, -1, 0, -4), Move(7, 1, 3, -2), Move(4, 1, 1, -1), Move(1, 4, 0, 0), Move(1, 7, 3, -4), Move(2, -1, 2, 0), Move(4, 4, 3, -4), Move(7, 4, 1, -4), Move(8, 0, 0, -4), Move(10, 1, 0, -4), Move(0, 8, 0, 0), Move(8, 4, 2, -4), Move(7, 5, 2, -3), Move(5, 5, 1, -2), Move(8, 2, 0, -4), Move(10, 4, 2, -4), Move(10, 2, 1, -4), Move(11, 4, 1, -4), Move(8, 1, 3, -1), Move(10, 3, 2, -3), Move(8, 5, 0, -2), Move(11, 3, 1, -4), Move(7, 7, 0, 0), Move(10, 7, 2, -4), Move(10, 5, 3, -4), Move(5, 7, 0, 0), Move(2, 4, 2, -1), Move(2, 5, 3, -3), Move(-1, 5, 1, 0), Move(-1, 4, 1, 0), Move(2, 8, 2, -3), Move(2, 7, 2, -3), Move(4, 7, 1, -2), Move(-1, 7, 0, 0), Move(-1, 6, 3, -3), Move(2, 9, 0, 0), Move(2, 10, 3, -4), Move(1, 9, 1, 0), Move(0, 10, 0, 0), Move(-2, 6, 2, 0), Move(-3, 6, 1, 0), Move(-1, 8, 0, 0), Move(-2, 7, 1, 0), Move(-3, 8, 0, 0), Move(8, 8, 2, -4), Move(8, 7, 3, -3), Move(9, 7, 1, -3), Move(7, 8, 0, 0), Move(7, 9, 3, -4), Move(4, 8, 3, -3), Move(1, 8, 1, -1), Move(-2, 5, 2, 0), Move(-4, 7, 0, 0), Move(1, 11, 0, 0), Move(1, 10, 3, -3), Move(0, 9, 2, -3), Move(-1, 10, 0, 0), Move(3, 10, 1, -4), Move(0, 11, 3, -4), Move(5, 8, 1, -1), Move(5, 10, 3, -4), Move(2, 11, 0, 0), Move(7, 10, 2, -4), Move(-2, 9, 2, -2), Move(-2, 8, 3, -3), Move(-4, 8, 1, 0), Move(-3, 7, 0, -1), Move(-1, 9, 2, -2), Move(-1, 11, 3, -4), Move(3, 11, 1, -4), Move(4, 10, 0, -1), Move(6, 10, 1, -3), Move(5, 11, 0, 0), Move(7, 11, 2, -4), Move(3, 12, 3, -4), Move(11, 5, 1, -4), Move(9, 1, 2, -2), Move(11, 1, 1, -4), Move(11, 2, 3, -1), Move(-1, 2, 2, 0), Move(4, 11, 0, -1), Move(6, 11, 1, -3), Move(7, 12, 2, -4), Move(7, 13, 3, -4), Move(6, 12, 2, -3), Move(6, 13, 3, -4), Move(5, 12, 2, -3), Move(4, 12, 1, -1), Move(4, 13, 3, -4), Move(5, 14, 2, -4), Move(5, 13, 3, -3), Move(6, 14, 2, -4), Move(3, 13, 1, 0), Move(-3, 9, 1, 0), Move(-3, 10, 3, -4), Move(8, 9, 0, -4), Move(9, 9, 1, -4), Move(8, 10, 0, -3), Move(9, 11, 2, -4)]

    # @time unit(board_template, moves_119)

    # min_accept_delta = -3

    # start_moves = random_completion(copy(board_template))
    # start_moves_points_hash = points_hash(start_moves)
    # pool_index = Dict(start_moves_points_hash => (start_moves, 0))

    # function exploit_reducer(a, b)
    #     t = 2
    #     (a_moves, a_visits) = a
    #     (b_moves, b_visits) = b
    #     a_score = length(a_moves)
    #     b_score = length(b_moves)
    #     sa = a_score - (a_visits / (a_score * t))
    #     sb = b_score - (b_visits / (b_score * t))
  
    #     if sa > sb || sa == sb #&& randbool()
    #         return a
    #     else
    #         return b
    #     end
    # end

    # function explore_reducer(a, b)
    #     t = 0.2
    #     (a_moves, a_visits) = a
    #     (b_moves, b_visits) = b
    #     a_score = length(a_moves)
    #     b_score = length(b_moves)
    #     sa = a_score - (a_visits / (a_score * t))
    #     sb = b_score - (b_visits / (b_score * t))
  
    #     if sa > sb || sa == sb #&& randbool()
    #         return a
    #     else
    #         return b
    #     end
    # end

    # step = 1

    # timer = Dates.now()

    # max_score = 0
    # max_moves = Move[]
    
    # while true
    #     curr_moves, curr_visits = reduce(exploit_reducer, values(pool_index))

    #     curr_moves_points_hash = points_hash(curr_moves)

    #     if !haskey(pool_index, curr_moves_points_hash)
    #         pool_index[curr_moves_points_hash] = (curr_moves, 0)
    #     else
    #         moves, visits = pool_index[curr_moves_points_hash]
    #         pool_index[curr_moves_points_hash] = (moves, visits + 1)
    #     end

    #     eval_moves = modification_triple(copy(board_template), curr_moves)
    #     curr_score = length(curr_moves)
    #     eval_score = length(eval_moves)
    #     eval_hash = hash(eval_moves)

    #     if (eval_score >= curr_score + min_accept_delta)
    #         eval_points_hash = points_hash(eval_moves)

    #         if !haskey(pool_index, eval_points_hash)
    #             pool_index[eval_points_hash] = (eval_moves, 0)
    #             if eval_score >= curr_score
    #                 indicator = "=>"
    #                 println("$step. $curr_score($curr_visits) $indicator $eval_score  $max_score")
    #             end
    #         else
    #             m, v  = pool_index[eval_points_hash]
    #             pool_index[eval_points_hash] = (eval_moves, v)               
    #         end
    #     end

    #     if eval_score > max_score
    #         println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    #         println(eval_moves)
    #         println("$eval_score")
    #         println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    #         max_score = eval_score
    #         max_moves = eval_moves
    #         max_moves_points_hash = points_hash(max_moves)
            
    #         before_size = length(pool_index)
    #         for pair in pairs(pool_index)
    #             pair_points_hash = pair[1]
    #             pair_value = pair[2]
    #             pair_moves, pair_visits = pair_value
    #             pair_score = length(pair_moves);

    #             if(pair_score < max_score + min_accept_delta)
    #                 pop!(pool_index, pair_points_hash)
    #             end
    #         end
    #         after_size = length(pool_index)

    #         println("clearing index $before_size -> $after_size")
    #     end

    #     if step % 10000 == 0
    #         current_time = Dates.now()
    #         elapsed = current_time - timer
    #         println("$step. $max_score ($elapsed) [index:$(length(pool_index))]")
    #         timer = current_time
    #     end
      
    #     step += 1

    # end

end

run();