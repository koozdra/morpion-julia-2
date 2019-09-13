import Dates
using Random
using StatsBase

mutable struct StateStat
    visits::Int64
    total_count::Int64
    total::Int64
    max::Int64
end

function build_state_stat(score)
    StateStat(1, 1, score, score)
end

struct Move
    x::Int8
    y::Int8
    direction::Int8
    start_offset::Int8
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

function pentasol_directions()
    return ['/','-','\\', '|']
end

function pentasol_move(move)
    pentasol_direction = pentasol_directions()[move.direction + 1]
    pentasol_offset = move.start_offset + 2
    x = move.x
    y = move.y
    return "($x,$y) $pentasol_direction $pentasol_offset"
end

function pentasol_representation(moves)
    pentasol_moves = map(move->pentasol_move(move), moves)
    preamble = ["GameType=5T", "(3,3)"]
    
    return join([preamble; pentasol_moves], '\n')
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

function remove_move_from_board(board::Array{UInt8,1}, move::Move)

end

function fill_board_with_moves(moves::Array{Move,1})
    board = zeros(UInt8, 40 * 40)

    for move in moves
        update_board(board, move)
    end

    board
end

function find_loose_moves(moves::Array{Move,1})
    board = fill_board_with_moves(moves)
    
    return filter(moves) do move
        board_value = board[board_index_at(move.x, move.y)]
        return board_value == 2 || board_value == 4 || board_value == 8 || board_value == 16
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


mutable struct morpion_evaluator
    curr_possible_moves::Array{Move,1}
    taken_moves::Array{Move,1}
    board::Array{UInt8,1}
end

function new_morpion_evaluator(board)
    morpion_evaluator(initial_moves(), Move[], board)
end

function evaluator_make_move(evaluator, move)
    push!(evaluator.taken_moves, move)
    update_board(evaluator.board, move)
    filter!((move)->is_move_valid(evaluator.board, move), evaluator.curr_possible_moves)
    created_moves = find_created_moves(evaluator.board, move.x, move.y)
    union!(evaluator.curr_possible_moves, created_moves)
end

function evaluator_random_completion(evaluator)
    while length(evaluator.curr_possible_moves) > 0
        move = evaluator.curr_possible_moves[rand(1:end)]
        evaluator_make_move(evaluator, move)
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

function eval_verbose(board, moves::Array{Move,1})
    curr_possible_moves = initial_moves()
    taken_moves = Move[]

    i = 1
  
    while length(curr_possible_moves) > 0
        println("Making move: $move")
        move = moves[i]
        push!(taken_moves, move)
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        created_moves = find_created_moves(board, move.x, move.y)
        union!(curr_possible_moves, created_moves)
        println(" possible moves: $curr_possible_moves")
        i += 1
    end

    println()

    println(length(taken_moves))
end

function eval_partial(board, moves::Array{Move,1})
    curr_possible_moves = initial_moves()
  
    for move in moves
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), curr_possible_moves)
        union!(curr_possible_moves, find_created_moves(board, move.x, move.y))
    end

    (board, curr_possible_moves)
end

function remove_loose_moves(moves)
    setdiff(moves, find_loose_moves(moves))
end

function make_move_on_board(taken_moves, board, possible_moves, move)
    push!(taken_moves, move)
    update_board(board, move)
    filter!((move)->is_move_valid(board, move), possible_moves)
    union!(possible_moves, find_created_moves(board, move.x, move.y))
end

function random_completion_from(board, possible_moves, taken_moves)
    curr_possible_moves = possible_moves
    while !isempty(curr_possible_moves)
        move = curr_possible_moves[rand(1:end)]
        make_move_on_board(taken_moves, board, curr_possible_moves, move)
    end
    taken_moves
end

function end_search(board_template,  min_accept_score, index, moves)
    reordered_moves = copy(moves)

    reordered_moves_score = length(reordered_moves)

    eval_moves = reordered_moves[1:(reordered_moves_score - 5)]

    evaled_template_board, possible_moves = eval_partial(copy(board_template), copy(eval_moves))

    search_counter = 0
    search_timeout = 20
    num_new_found = 0
    while search_counter < search_timeout
        rando_moves = random_completion_from(copy(evaled_template_board), copy(possible_moves), copy(eval_moves))
        rando_score = length(rando_moves)
        rando_points_hash = points_hash(rando_moves)
        if !haskey(index, rando_points_hash) && (rando_score >= min_accept_score)
            # println(length(rando_moves))
            index[rando_points_hash] = rando_moves
            num_new_found += 1
            search_counter = 0
        end
        search_counter += 1
    end

    if num_new_found > 0
        end_search(board_template, min_accept_score, index, eval_moves)
    end
    
end

function end_search(board_template,  min_accept_score, moves)
    index = Dict()
    end_search(board_template,  min_accept_score, index, moves)
    index
end

function explore_reducer(a, b)
    t = 200
    (a_moves, a_visits, a_last_visited_index) = a
    (b_moves, b_visits, b_last_visitid_index) = b
    a_score = length(a_moves)
    b_score = length(b_moves)
    sa = a_score - (a_visits / t)
    sb = b_score - (b_visits / t)

    if sa > sb || sa == sb && rand(Bool)
        return a
    else
        return b
    end
end

function reorder_moves_by_layers(board, moves::Array{Move,1}, possible_moves::Array{Move,1}, taken_moves::Array{Move,1}, taboo_moves::Array{Move,1})
    layer_possible_moves = setdiff(possible_moves, taboo_moves)
    layer_moves = intersect(layer_possible_moves, moves)
    moves_not_taken = setdiff(layer_possible_moves, moves)

    for move in layer_moves
        push!(taken_moves, move)
        update_board(board, move)
        filter!((move)->is_move_valid(board, move), possible_moves)
        union!(possible_moves, find_created_moves(board, move.x, move.y))
    end

    if (!isempty(layer_possible_moves))
        reorder_moves_by_layers(board, moves, possible_moves, taken_moves, [taboo_moves; moves_not_taken])
    end
end

function reorder_moves_by_layers(board, moves)
    taken_moves = Move[]
    reorder_moves_by_layers(board, moves, initial_moves(), taken_moves, Move[])
    taken_moves
end

mutable struct Subject
    step::UInt64
    pool_index::Dict{UInt64,Tuple{Array{Move,1},Int64,Int64}}
    end_searched_index::Dict{UInt64, Bool}
    max_score::UInt64
    max_moves::Array{Move}
end

function build_initial_pool_index()
    start_moves = random_completion(copy(board_template))
    start_moves_points_hash = points_hash(start_moves)
    Dict(start_moves_points_hash => (start_moves, 0, 0))
end

function build_subject(board_template)
    start_moves = random_completion(copy(board_template))
    start_moves_points_hash = points_hash(start_moves)
    pool_index = Dict(start_moves_points_hash => (start_moves, 0, 0))
    Subject(1, pool_index, Dict{UInt64, Bool}(), 0, [])
end

function visit_subject(subject, board_template)
    pool_index = subject.pool_index
    step = subject.step
    end_searched_index = subject.end_searched_index
    max_score = subject.max_score
    max_moves = subject.max_moves

    min_accept_delta = -10

    curr_moves, curr_visits = reduce(explore_reducer, values(pool_index))
    
    curr_score = length(curr_moves)
    curr_moves_points_hash = points_hash(curr_moves)

    if curr_score > max_score || max_score == 0
        subject.max_score = curr_score
        subject.max_moves = curr_moves
    end

    if !haskey(end_searched_index, curr_moves_points_hash) && curr_score > 100
        end_search_index = Dict()
        end_search_start_time = Dates.now()
        end_search(board_template, curr_score + min_accept_delta, end_search_index, curr_moves)
        end_search_end_time = Dates.now()

        for pair in pairs(end_search_index)
            pair_points_hash, pair_moves = pair
            pair_score = length(pair_moves)
            
            if !haskey(pool_index, pair_points_hash)
                pool_index[pair_points_hash] = (pair_moves, 0, step)
            end
        end

        end_searched_index[curr_moves_points_hash] = true
    end

    if !haskey(pool_index, curr_moves_points_hash)
        pool_index[curr_moves_points_hash] = (curr_moves, 0, step)
    else
        moves, visits, last_visited_step = pool_index[curr_moves_points_hash]
        pool_index[curr_moves_points_hash] = (moves, visits + 1, step)
    end

    eval_moves = modification_triple(copy(board_template), curr_moves)
    curr_score = length(curr_moves)
    eval_score = length(eval_moves)

    if (eval_score >= curr_score + min_accept_delta)
        eval_points_hash = points_hash(eval_moves)

        # if a new configuration is found
        if !haskey(pool_index, eval_points_hash)
            # enter the configuration into the index
            pool_index[eval_points_hash] = (eval_moves, 0, step)

        else
            m, v, t  = pool_index[eval_points_hash]
            pool_index[eval_points_hash] = (eval_moves, v, t)
        end
    end

    if step % 10000 == 0
        max_age = 10000
        for pair in pairs(pool_index)
            pair_points_hash, pair_value = pair
            pair_moves, pair_visits, pair_last_visit_step = pair_value
            pair_score = length(pair_moves)
            age = step - pair_last_visit_step
            if(age > max_age)
                pop!(pool_index, pair_points_hash)
            end
        end
    end
    
    subject.step += 1
end

function build_new_states(taken_moves, move)
    cat(taken_moves, [move], dims = 1)
end

function build_state_hash(moves)
    hash(moves)
end

function has_state_value(state_stats, taken_moves, move)
    new_state = build_new_states(taken_moves, move)
    new_state_hash = build_state_hash(new_state)
    haskey(state_stats, new_state_hash)
end

function evaluator_with_moves(board, moves)
    n = new_morpion_evaluator(board)
    for move in moves
        evaluator_make_move(n, move)
    end
    n
end

function random_completion_from(board, taken_moves, move)
    n = new_morpion_evaluator(board)
    for taken_move in taken_moves
        evaluator_make_move(n, taken_move)
    end
    evaluator_random_completion(n)
    n.taken_moves
end

# function first_visit(state_stats, board, taken_moves, move)
#     random_completion_moves = random_completion_from(board, taken_moves, move)

#     new_state = build_new_states(taken_moves, move)
#     new_state_hash = build_state_hash(new_state)

#     state_stats[new_state_hash] = (1, length(random_completion_moves))
# end

function print_root_stats(state_stats)
    for move in initial_moves()
        state = [move]
        state_hash = build_state_hash(state)
        if haskey(state_stats, state_hash)
            stat = state_stats[state_hash]
            score = state_score(state_stats, state_hash)
            println("$move $stat $score")
        else
            println("$move *")
        end
    end
end

function arg_max_by(f, arr)
    reduce((sum, num) -> f(num) > f(sum) ? num : sum, arr, init=first(arr))
end

function mcts_expand(evaluator, move)

end

function evaluator_score(evaluator)
    length(evaluator.taken_moves)
end

function visit_state(state_stats, state_hash)
    state_stat = state_stats[state_hash]
    
    # state_stats[state_hash] = (stat_visits + 1, stat_score)
    state_stat.visits += 1
end

function update_state_score(state_stats, state_hash, score)
    state_stat = state_stats[state_hash]
    
    state_stat.max = max(state_stat.max, score)
    state_stat.total += score
    state_stat.total_count += 1
end

function state_score(state_stats, state_hash)
    state_stat = state_stats[state_hash]
    state_stat.total / state_stat.total_count
end

# select children til leaf node is reached
function mcts_selection(board_template, state_stats, evaluator)
    # TODO optimization - cache if all children visited in state stats and don't do this filter
    unvisited_possible_moves = filter((move)->!has_state_value(state_stats, evaluator.taken_moves, move), evaluator.curr_possible_moves)
    curr_taken_moves = copy(evaluator.taken_moves)

    if length(unvisited_possible_moves) > 0
        random_unvisited_move = unvisited_possible_moves[rand(1:end)]
        evaluator_make_move(evaluator, random_unvisited_move)
        evaluator_random_completion(evaluator)
        rollout_score = evaluator_score(evaluator)

        new_state = build_new_states(curr_taken_moves, random_unvisited_move)
        new_state_hash = build_state_hash(new_state)

        # state_stats[new_state_hash] = (1, rollout_score)
        state_stats[new_state_hash] = build_state_stat(rollout_score)


        # println("$random_unvisited_move $rollout_score ($(length(unvisited_possible_moves)))")

        return rollout_score
    end

    # TODO more here
    if (length(evaluator.curr_possible_moves) == 0)
        # println("end $(length(evaluator.taken_moves)) $(build_state_hash(evaluator.taken_moves))")
        return length(evaluator.taken_moves)
    end

    

    # move_score_ucb = function (move)

    # end

    

    # choose child to visits
    # e-greedy
    move_score_state_score = function (move)
        new_state = build_new_states(evaluator.taken_moves, move)
        new_state_hash = build_state_hash(new_state)
        state_score(state_stats, new_state_hash)
    end
    explore = rand(1:10) == 1
    best_move = explore ? evaluator.curr_possible_moves[rand(1:end)] : arg_max_by(move_score_state_score, evaluator.curr_possible_moves)
    

    # max_score = 0
    # total_visits = reduce(function (sum, move) 
    #     new_state = build_new_states(curr_taken_moves, move)
    #     new_state_hash = build_state_hash(new_state)
    #     state_stat = state_stats[new_state_hash]
    #     score = state_score(state_stats, new_state_hash)
    #     max_score = max(max_score, score)
    #     sum + state_stat.visits
    # end, evaluator.curr_possible_moves, init=0)

    # best_move = arg_max_by(function (move)
    #     new_state = build_new_states(curr_taken_moves, move)
    #     new_state_hash = build_state_hash(new_state)
    #     state_stat = state_stats[new_state_hash]
    #     score = state_score(state_stats, new_state_hash)
    #     (score / max_score) + sqrt(2 * (log(total_visits)/state_stat.visits))
    # end, evaluator.curr_possible_moves)

    # println("best move $best_move")

    evaluator_make_move(evaluator, best_move)

    # new_state = build_new_states(curr_taken_moves, best_move)
    new_state_hash = build_state_hash(evaluator.taken_moves)

    visit_state(state_stats, new_state_hash)

    rollout_score = mcts_selection(board_template, state_stats, evaluator)

    # println("rollout scroe ", rollout_score)
    # println("curr_taken_moves ", curr_taken_moves)

    update_state_score(state_stats, build_state_hash(curr_taken_moves), rollout_score)

    rollout_score
    
end

function switch_search(board_template, min_accept_score_modifier, moves)
    curr_possible_moves = initial_moves()
    pool_index = Dict{UInt64,Tuple{Array{Move,1},Int64,Int64}}()

    evaluator = new_morpion_evaluator(copy(board_template))
    moves_index = 1
    searches = 0
    # morpion_dna_template = generate_dna(moves)

    while (!isempty(evaluator.curr_possible_moves))
        move = moves[moves_index]
        move_dna_index = dna_index(move)

        for possible_move in evaluator.curr_possible_moves
            # morpion_dna = copy(morpion_dna_template)
            morpion_dna = generate_dna(moves)

            morpion_dna[move_dna_index] = -1000
            morpion_dna[dna_index(possible_move)] = 1000

            eval_moves = eval_dna(copy(board_template), morpion_dna)
            eval_moves_hash = points_hash(eval_moves)

            searches += 1

            eval_score = length(eval_moves)

            if (eval_score > (length(moves) + min_accept_score_modifier))
                pool_index[eval_moves_hash] = (eval_moves, 0, 0)
            end

            
            # println("$(length(moves)) => $(length(eval_moves)) ($(length(test_index)))")
        end
        
        moves_index += 1
        evaluator_make_move(evaluator, move)
    end

    (pool_index, searches)
end

function switch_search_exploit_reducer_pairs(a, b)
    t = 100
    (a_key, (a_moves, a_visits, a_last_visited_index)) = a
    (b_key, (b_moves, b_visits, b_last_visitid_index)) = b
    a_score = length(a_moves)
    b_score = length(b_moves)
    sa = a_score - (a_visits / t)
    sb = b_score - (b_visits / t)

    if sa > sb || sa == sb && rand(Bool)
        return a
    else
        return b
    end
end

function switch_search_explore_reducer_pairs(a, b)
    t = 0.1
    (a_key, (a_moves, a_visits, a_last_visited_index)) = a
    (b_key, (b_moves, b_visits, b_last_visitid_index)) = b
    a_score = length(a_moves)
    b_score = length(b_moves)
    sa = a_score - (a_visits / t)
    sb = b_score - (b_visits / t)

    if sa > sb || sa == sb && rand(Bool)
        return a
    else
        return b
    end
end



function run() 
    board_template = generate_initial_board()

    step = 0
    max_moves = []
    max_score = 0
    total_searches = 0

    pool_index = Dict{UInt64,Tuple{Array{Move,1},Int64,Int64}}()
    taboo_index = Dict{UInt64, Int64}()
    taboo_visits = 10
    # start_moves = Move[Move(7, 7, 0, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(0, 7, 3, -4), Move(3, 4, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(7, 9, 1, -4), Move(-1, 3, 1, 0), Move(7, 2, 2, -2), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(4, 5, 2, -2), Move(5, 4, 0, -3), Move(4, 7, 3, -2), Move(5, 7, 1, -3), Move(2, 10, 0, 0), Move(2, 9, 3, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(3, 5, 2, 0), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(4, 4, 2, -1), Move(2, 4, 1, 0), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(1, 7, 0, 0), Move(5, 2, 3, 0), Move(2, 0, 1, 0), Move(7, 4, 3, -2), Move(5, 10, 3, -4), Move(2, 5, 0, -1), Move(2, 2, 3, 0), Move(-1, 5, 0, 0), Move(-2, 4, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(-1, 4, 1, -1), Move(-1, 1, 3, 0), Move(0, 2, 2, -1), Move(1, 1, 0, -3), Move(-2, 7, 1, 0), Move(1, 2, 1, -3), Move(2, 1, 0, -3), Move(0, 1, 1, -1), Move(-1, 6, 0, -1), Move(1, 8, 2, -2), Move(7, 10, 2, -4), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 4, 1, -4), Move(10, 2, 0, -4), Move(4, 10, 1, -1), Move(4, 2, 1, -2), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(1, -1, 2, 0), Move(2, -2, 3, 0), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(0, 0, 0, -2), Move(0, -1, 3, 0), Move(-1, -2, 2, 0), Move(-1, -1, 2, 0), Move(-2, -1, 1, 0), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(8, 1, 2, -2), Move(10, -1, 0, -4), Move(11, 1, 1, -4), Move(8, -1, 1, -2), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(7, -2, 1, -2), Move(6, -3, 2, 0), Move(7, -4, 3, 0), Move(4, -1, 0, -1), Move(3, -1, 1, -1), Move(1, -3, 2, 0), Move(-1, 0, 2, -1), Move(-1, -3, 3, 0), Move(-2, 0, 1, 0), Move(-2, 1, 3, -1)]
    start_moves = random_completion(copy(board_template))
    pool_index[points_hash(start_moves)] = (start_moves, 0, 0)

    while true
        is_explore = false
        if step % 2 == 0
            (curr_moves_points_hash, (curr_moves, curr_visits, curr_last_visited_step)) = reduce(switch_search_exploit_reducer_pairs, pairs(pool_index))
        else
            is_explore = true
            (curr_moves_points_hash, (curr_moves, curr_visits, curr_last_visited_step)) = reduce(switch_search_explore_reducer_pairs, pairs(pool_index))
        end

        curr_score = length(curr_moves)
        curr_age = step - curr_last_visited_step

        # curr_moves_points_hash = points_hash(curr_moves)
        (switch_search_results, num_searches) = switch_search(board_template, -10, curr_moves)

        total_searches += num_searches
        
        new_found = 0
        has_improvement = false
        for pair in pairs(switch_search_results)
            pair_points_hash, pair_value = pair
            pair_moves, pair_visits, pair_last_visit_step = pair_value
            pair_score = length(pair_moves)

            if pair_score > max_score
                max_score = pair_score
                max_moves = pair_moves

                println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                println("$(max_score)")
                println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            end
            
            
            if !haskey(taboo_index, pair_points_hash)
                if !haskey(pool_index, pair_points_hash)
                    t_moves, t_visits, t_last = pair_value
                    pool_index[pair_points_hash] = (t_moves, t_visits, step)
                    new_found += 1

                    if (pair_score >= curr_score)
                        has_improvement = true
                        println("  $curr_score => $pair_score")
                    end
                else
                    t_moves, t_visits, t_step = pool_index[pair_points_hash]
                    pool_index[pair_points_hash] = (pair_moves, t_visits, t_step)
                end
            end
        end

        # dimitri
        if has_improvement#new_found > 4 #&& !is_explore
            t_moves, t_visits, t_step = pool_index[curr_moves_points_hash]
            pool_index[curr_moves_points_hash] = (t_moves, 0, t_step)
        end

        println("$(total_searches)($(step)). $(length(curr_moves)) ($(curr_visits), $(curr_age), $(length(switch_search_results))($(new_found)), $(max_score), $(length(pool_index)))")

        t_curr_moves, t_curr_visits, t_step = pool_index[curr_moves_points_hash]
        pool_index[curr_moves_points_hash] = (t_curr_moves, t_curr_visits + 1, step)
        step += 1

        if curr_visits >= taboo_visits
            taboo_index[curr_moves_points_hash] = curr_score
            pop!(pool_index, curr_moves_points_hash)

            println(" --- $(curr_score)")
        end

        if step % 1000 == 0
            
            max_age = 1000
            before_size = length(pool_index)
            for pair in pairs(pool_index)
                pair_points_hash, pair_value = pair
                pair_moves, pair_visits, pair_last_visit_step = pair_value
                pair_score = length(pair_moves)
                age = step - pair_last_visit_step
                if(age > max_age)
                    pop!(pool_index, pair_points_hash)
                end
            end
            println("cleaning $(before_size) -> $(length(pool_index))")
        end
    end

    # test_index = Dict{UInt64,Int64}()
    # max_score = 0
    # max_moves = []

    # for i in 1:100
    #     curr_possible_moves = initial_moves()

    #     #110
    #     # moves = Move[Move(7, 7, 0, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(0, 7, 3, -4), Move(3, 4, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(7, 9, 1, -4), Move(-1, 3, 1, 0), Move(7, 2, 2, -2), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(4, 5, 2, -2), Move(5, 4, 0, -3), Move(4, 7, 3, -2), Move(5, 7, 1, -3), Move(2, 10, 0, 0), Move(2, 9, 3, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(3, 5, 2, 0), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(4, 4, 2, -1), Move(2, 4, 1, 0), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(1, 7, 0, 0), Move(5, 2, 3, 0), Move(2, 0, 1, 0), Move(7, 4, 3, -2), Move(5, 10, 3, -4), Move(2, 5, 0, -1), Move(2, 2, 3, 0), Move(-1, 5, 0, 0), Move(-2, 4, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(-1, 4, 1, -1), Move(-1, 1, 3, 0), Move(0, 2, 2, -1), Move(1, 1, 0, -3), Move(-2, 7, 1, 0), Move(1, 2, 1, -3), Move(2, 1, 0, -3), Move(0, 1, 1, -1), Move(-1, 6, 0, -1), Move(1, 8, 2, -2), Move(7, 10, 2, -4), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 4, 1, -4), Move(10, 2, 0, -4), Move(4, 10, 1, -1), Move(4, 2, 1, -2), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(1, -1, 2, 0), Move(2, -2, 3, 0), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(0, 0, 0, -2), Move(0, -1, 3, 0), Move(-1, -2, 2, 0), Move(-1, -1, 2, 0), Move(-2, -1, 1, 0), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(8, 1, 2, -2), Move(10, -1, 0, -4), Move(11, 1, 1, -4), Move(8, -1, 1, -2), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(7, -2, 1, -2), Move(6, -3, 2, 0), Move(7, -4, 3, 0), Move(4, -1, 0, -1), Move(3, -1, 1, -1), Move(1, -3, 2, 0), Move(-1, 0, 2, -1), Move(-1, -3, 3, 0), Move(-2, 0, 1, 0), Move(-2, 1, 3, -1)]

    #     # derived 111 from 110 above
    #     # moves = Move[Move(2, 9, 1, 0), Move(7, 7, 0, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(0, 7, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(-1, 3, 1, 0), Move(7, 2, 2, -2), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(2, 10, 3, -4), Move(5, 7, 0, -3), Move(4, 7, 1, -2), Move(4, 5, 3, 0), Move(3, 4, 2, -1), Move(5, 4, 0, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(4, 4, 2, -1), Move(2, 4, 1, 0), Move(2, 0, 1, 0), Move(5, 10, 3, -4), Move(7, 10, 2, -4), Move(4, 10, 1, -1), Move(3, 5, 3, -3), Move(7, 9, 2, -4), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(1, 7, 0, 0), Move(5, 2, 3, 0), Move(7, 4, 3, -2), Move(2, 5, 0, -1), Move(2, 2, 3, 0), Move(-1, 5, 0, 0), Move(-2, 4, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(-1, 4, 1, -1), Move(-1, 1, 3, 0), Move(0, 2, 2, -1), Move(1, 1, 0, -3), Move(-2, 7, 1, 0), Move(1, 2, 1, -3), Move(2, 1, 0, -3), Move(0, 1, 1, -1), Move(-1, 6, 0, -1), Move(1, 8, 2, -2), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 4, 1, -4), Move(10, 2, 0, -4), Move(4, 2, 1, -2), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(1, -1, 2, 0), Move(2, -2, 3, 0), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(0, 0, 0, -2), Move(0, -1, 3, 0), Move(-1, -2, 2, 0), Move(-1, -1, 2, 0), Move(-2, -1, 1, 0), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(8, 1, 2, -2), Move(10, -1, 0, -4), Move(11, 1, 1, -4), Move(8, -1, 1, -2), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(7, -2, 1, -2), Move(6, -3, 2, 0), Move(7, -4, 3, 0), Move(4, -1, 0, -1), Move(3, -1, 1, -1), Move(1, -3, 2, 0), Move(-1, 0, 2, -1), Move(-1, -3, 3, 0), Move(-2, 0, 1, 0), Move(-2, 1, 3, -1), Move(3, -2, 3, 0)]

    #     # derived 113 from above
    #     # moves = Move[Move(0, 2, 3, 0), Move(2, 9, 1, 0), Move(7, 7, 0, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(-1, 3, 1, 0), Move(7, 2, 2, -2), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(2, 10, 3, -4), Move(5, 7, 0, -3), Move(4, 7, 1, -2), Move(4, 5, 3, 0), Move(3, 4, 2, -1), Move(5, 4, 0, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(4, 4, 2, -1), Move(2, 4, 1, 0), Move(2, 0, 1, 0), Move(5, 10, 3, -4), Move(7, 10, 2, -4), Move(4, 10, 1, -1), Move(3, 5, 3, -3), Move(7, 9, 2, -4), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(1, 7, 0, 0), Move(5, 2, 3, 0), Move(7, 4, 3, -2), Move(2, 5, 0, -1), Move(2, 2, 3, 0), Move(-1, 5, 0, 0), Move(-2, 4, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(-1, 4, 1, -1), Move(-1, 1, 3, 0), Move(1, 1, 0, -3), Move(1, 2, 1, -3), Move(2, 1, 0, -3), Move(0, 1, 1, -1), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 4, 1, -4), Move(10, 2, 0, -4), Move(4, 2, 1, -2), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(1, -1, 2, 0), Move(2, -2, 3, 0), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(0, 0, 0, -2), Move(-1, -1, 2, 0), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(8, 1, 2, -2), Move(10, -1, 0, -4), Move(11, 1, 1, -4), Move(8, -1, 1, -2), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(7, -2, 1, -2), Move(6, -3, 2, 0), Move(7, -4, 3, 0), Move(4, -1, 0, -1), Move(3, -1, 1, -1), Move(1, -3, 2, 0), Move(3, -2, 3, 0), Move(-2, 0, 2, 0), Move(-1, 0, 1, -1), Move(-2, -1, 2, 0), Move(0, -1, 1, -2), Move(-1, -2, 2, 0), Move(-1, -3, 3, 0), Move(-2, 1, 3, -1), Move(0, -2, 3, 0), Move(1, -2, 1, -2), Move(2, -4, 0, -4), Move(2, -3, 0, -4), Move(1, -4, 2, 0), Move(1, -5, 3, 0)]

    #     #117
    #     # moves = Move[Move(0, 2, 3, 0), Move(2, 9, 1, 0), Move(7, 7, 0, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(-1, 3, 1, 0), Move(7, 2, 2, -2), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(2, 10, 3, -4), Move(5, 7, 0, -3), Move(4, 7, 1, -2), Move(4, 5, 3, 0), Move(3, 4, 2, -1), Move(5, 4, 0, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(4, 4, 2, -1), Move(2, 4, 1, 0), Move(2, 0, 1, 0), Move(5, 10, 3, -4), Move(7, 10, 2, -4), Move(4, 10, 1, -1), Move(3, 5, 3, -3), Move(7, 9, 2, -4), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(1, 7, 0, 0), Move(5, 2, 3, 0), Move(7, 4, 3, -2), Move(2, 5, 0, -1), Move(2, 2, 3, 0), Move(-1, 5, 0, 0), Move(-2, 4, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(-1, 4, 1, -1), Move(-1, 1, 3, 0), Move(1, 1, 0, -3), Move(1, 2, 1, -3), Move(2, 1, 0, -3), Move(0, 1, 1, -1), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 4, 1, -4), Move(10, 2, 0, -4), Move(4, 2, 1, -2), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(1, -1, 2, 0), Move(2, -2, 3, 0), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(0, 0, 0, -2), Move(-1, -1, 2, 0), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(7, -2, 3, 0), Move(-2, 0, 2, 0), Move(-1, 0, 1, -1), Move(-2, -1, 2, 0), Move(0, -1, 1, -2), Move(-1, -2, 2, 0), Move(-1, -3, 3, 0), Move(-2, 1, 3, -1), Move(0, -2, 3, 0), Move(8, -1, 2, -1), Move(10, -1, 1, -4), Move(8, 1, 0, -2), Move(11, 1, 1, -4), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(4, -3, 2, 0), Move(4, -2, 1, 0), Move(4, -1, 3, -2), Move(3, -1, 1, -1), Move(1, -3, 2, 0), Move(3, -2, 3, 0), Move(1, -2, 1, -2), Move(2, -4, 0, -4), Move(2, -3, 0, -4), Move(1, -4, 2, 0), Move(1, -5, 3, 0), Move(3, -3, 2, -2), Move(0, -3, 1, 0), Move(2, -5, 0, -4), Move(2, -6, 3, 0)]

    #     #120
    #     # moves = Move[Move(0, 2, 3, 0), Move(2, 9, 1, 0), Move(7, 7, 0, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(-1, 3, 1, 0), Move(7, 2, 2, -2), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(2, 10, 3, -4), Move(5, 7, 0, -3), Move(4, 7, 1, -2), Move(4, 5, 3, 0), Move(3, 4, 2, -1), Move(5, 4, 0, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(4, 4, 2, -1), Move(2, 4, 1, 0), Move(2, 0, 1, 0), Move(5, 10, 3, -4), Move(7, 10, 2, -4), Move(4, 10, 1, -1), Move(3, 5, 3, -3), Move(-1, 1, 2, 0), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(1, 7, 0, 0), Move(5, 2, 3, 0), Move(7, 4, 3, -2), Move(2, 5, 0, -1), Move(2, 2, 3, 0), Move(-1, 5, 0, 0), Move(-2, 4, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(-1, 4, 1, -1), Move(1, 1, 0, -3), Move(1, 2, 1, -3), Move(2, 1, 0, -3), Move(0, 1, 1, -1), Move(4, 2, 1, -2), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(1, -1, 2, 0), Move(2, -2, 3, 0), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(0, 0, 0, -2), Move(-1, -1, 2, 0), Move(-1, 0, 3, -1), Move(-2, 0, 1, 0), Move(-2, -1, 2, 0), Move(0, -1, 1, -2), Move(-1, -2, 2, 0), Move(-2, 1, 3, -1), Move(0, -2, 3, 0), Move(-1, 6, 3, -3), Move(-2, 7, 0, 0), Move(0, 7, 1, -2), Move(1, 8, 2, -2), Move(7, 9, 2, -4), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 4, 1, -4), Move(10, 2, 0, -4), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(7, -2, 3, 0), Move(8, -1, 2, -1), Move(10, -1, 1, -4), Move(8, 1, 0, -2), Move(11, 1, 1, -4), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(4, -3, 2, 0), Move(4, -2, 1, 0), Move(4, -1, 3, -2), Move(3, -1, 1, -1), Move(1, -3, 2, 0), Move(3, -2, 3, 0), Move(1, -2, 1, -2), Move(2, -4, 0, -4), Move(2, -3, 0, -4), Move(1, -4, 2, 0), Move(1, -5, 3, 0), Move(3, -3, 2, -2), Move(0, -3, 1, 0), Move(2, -5, 0, -4), Move(2, -6, 3, 0)]

    #     #121
    #     moves = Move[Move(7, 2, 2, -2), Move(0, 2, 3, 0), Move(2, 9, 1, 0), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(9, 7, 3, -4), Move(2, 8, 1, 0), Move(2, 7, 2, -2), Move(-1, 3, 1, 0), Move(10, 3, 1, -4), Move(4, 6, 1, -4), Move(5, 6, 1, -1), Move(2, 10, 3, -4), Move(5, 7, 0, -3), Move(4, 7, 1, -2), Move(4, 5, 3, 0), Move(3, 4, 2, -1), Move(5, 4, 0, -3), Move(6, 5, 0, -4), Move(4, 3, 2, -1), Move(6, 4, 3, -2), Move(5, 5, 0, -3), Move(2, 0, 1, 0), Move(5, 10, 3, -4), Move(7, 10, 2, -4), Move(4, 10, 1, -1), Move(3, 5, 3, -3), Move(7, 5, 1, -4), Move(5, 3, 2, 0), Move(5, 2, 3, 0), Move(7, 4, 3, -2), Move(2, 5, 0, -1), Move(7, 9, 2, -4), Move(4, 2, 1, -1), Move(1, -1, 2, 0), Move(4, 4, 1, -1), Move(7, 7, 2, -4), Move(1, 7, 0, 0), Move(4, 1, 3, 0), Move(2, -1, 2, 0), Move(6, -1, 0, -4), Move(6, -2, 3, 0), Move(7, 8, 3, -2), Move(8, 7, 0, -3), Move(10, 7, 1, -4), Move(8, 5, 2, -2), Move(11, 2, 0, -4), Move(8, 4, 3, -1), Move(10, 2, 0, -4), Move(5, 1, 2, 0), Move(7, 1, 1, -4), Move(7, -1, 0, -4), Move(10, 4, 0, -4), Move(8, 2, 2, -2), Move(9, 2, 1, -2), Move(10, 1, 0, -4), Move(10, 0, 3, 0), Move(9, 1, 0, -3), Move(8, 0, 2, -2), Move(9, -1, 0, -4), Move(9, 0, 3, -1), Move(7, 0, 1, -1), Move(7, -2, 3, 0), Move(8, -1, 2, -1), Move(10, -1, 1, -4), Move(8, 1, 0, -2), Move(11, 1, 1, -4), Move(8, -2, 3, 0), Move(7, -3, 2, 0), Move(5, -1, 0, -2), Move(5, -2, 3, 0), Move(9, -2, 0, -4), Move(4, -3, 2, 0), Move(4, -2, 1, 0), Move(4, -1, 3, -2), Move(3, -1, 1, -1), Move(3, -2, 3, 0), Move(11, 4, 1, -4), Move(-1, 5, 2, 0), Move(2, 2, 0, -3), Move(2, 4, 3, -2), Move(-1, 1, 2, 0), Move(1, 5, 1, -2), Move(-1, 7, 0, 0), Move(-2, 2, 2, 0), Move(1, 4, 3, -1), Move(-1, 2, 2, 0), Move(1, 2, 1, -3), Move(-1, 4, 1, 0), Move(2, 1, 0, -3), Move(2, -2, 3, 0), Move(0, 0, 0, -2), Move(-1, 6, 3, -3), Move(-2, 7, 0, 0), Move(0, 7, 1, -2), Move(1, 8, 2, -2), Move(1, -3, 2, 0), Move(12, 5, 2, -4), Move(1, 1, 0, -2), Move(0, 1, 1, -1), Move(1, 0, 3, -1), Move(-2, 3, 0, 0), Move(-1, -1, 2, 0), Move(-1, 0, 3, -1), Move(-2, 0, 1, 0), Move(-2, -1, 2, 0), Move(0, -1, 1, -2), Move(-1, -2, 2, 0), Move(0, -2, 3, 0), Move(1, -2, 1, -2), Move(2, -4, 0, -4), Move(-2, 1, 3, -2), Move(2, -3, 0, -4), Move(1, -4, 2, 0), Move(1, -5, 3, 0), Move(3, -3, 2, -2), Move(0, -3, 1, 0), Move(2, -5, 0, -4), Move(2, -6, 3, 0)]

    #     evaluator = new_morpion_evaluator(copy(board_template))
    #     moves_index = 1



    #     while (!isempty(evaluator.curr_possible_moves))

    

    #         move = moves[moves_index]
    #         move_dna_index = dna_index(move)

    #         # println()
    #         # println("$(moves_index): $(move)")

    #         for possible_move in evaluator.curr_possible_moves
    #             board = copy(board_template)
    #             morpion_dna = generate_dna(moves)
                
    #             morpion_dna[move_dna_index] = -1000
    #             morpion_dna[dna_index(possible_move)] = 1000

    #             eval_moves = eval_dna(board, morpion_dna)
    #             eval_moves_hash = points_hash(eval_moves)

    #             eval_score = length(eval_moves)

    #             if eval_score > max_score
    #                 max_score = eval_score
    #                 max_moves = eval_moves
    #             end

    #             if (eval_score > (length(moves) - 10))
    #                 test_index[eval_moves_hash] = eval_score
    #             end

                
    #             # println("$(length(moves)) => $(length(eval_moves)) ($(length(test_index)))")
    #         end

            
            
    #         moves_index += 1
    #         evaluator_make_move(evaluator, move)
    #     end

    #     results = collect(values(test_index))

    #     println()
    #     println("$(i): $(length(results))")
    #     println(sort(results))
    # end

    # println(max_moves)




    # ----------------------------------------------------------------------------------------

    # board_template = generate_initial_board()



    # state_stats = Dict()

    # state_stats[build_state_hash([])] = build_state_stat(0)

    
    # curr_possible_moves = initial_moves()
    # unvisited_possible_moves = filter((move)->!has_state_value(state_stats, [], move), curr_possible_moves)
    # while length(unvisited_possible_moves) > 0
    #     random_unvisited_possible_move = unvisited_possible_moves[rand(1:end)]
    #     first_visit(state_stats, copy(board_template), [], random_unvisited_possible_move)
    #     unvisited_possible_moves = filter((move)->!has_state_value(state_stats, [], move), curr_possible_moves)
    # end

    # print_root_stats(state_stats)
    # while true
    #     for i in 1:100
    #         mcts_selection(copy(board_template), state_stats, new_morpion_evaluator(copy(board_template)))
    #     end
    #     println()
    #     print_root_stats(state_stats)
    # end

    


    
    



    # taken_moves = Move[]

    # i = 1
  
    # while length(curr_possible_moves) > 0
    #     move = reduce(possible_move_reducer, curr_possible_moves)
    #     push!(taken_moves, move)
    #     update_board(board, move)
    #     filter!((move)->is_move_valid(board, move), curr_possible_moves)
    #     created_moves = find_created_moves(board, move.x, move.y)
    #     union!(curr_possible_moves, created_moves)

    #     i += 1
    # end

    # taken_moves


    # ------------------------------------------------------------

    # board_template = generate_initial_board()
    # # subject = build_subject(board_template)


    # subjects = Subject[]

    # for i in 1:20
    #     push!(subjects, build_subject(board_template))
    # end

    # iterations = 1000

    # max_score = 0
    # max_moves = []

    # step = 1

    # while true

    #     for i in 1:iterations
    #         # a/b test
    #         # for subject in subjects
    #         #     visit_subject(subject, board_template)
    #         # end

    #         #epsilon greedy
    #         # if rand(Bool)# > 0.5
    #         #     subject = maxby(function(subject)
    #         #         subject.max_score
    #         #     end, subjects)
    #         # else
    #         #     subject = subjects[rand(1:end)]
    #         # end

    #         #UCB TODO
    #         total_score = 0
    #         for subject in subjects
    #             total_score += subject.max_score
    #         end
    #         subject = maxby(function(subject)
    #             ucb = (subject.max_score / total_score) + √(200 * (log(step) / subject.step))

    #             # println("$(subject.max_score) $(ucb)")

    #             # readline()

    #             ucb
    #         end, subjects)

    #         visit_subject(subject, board_template)

    #         step = step + 1
    #     end






    #     println()
    #     println(max_score)
    #     println(max_moves)
    #     println()

    #     max_score = 0
    #     max_moves = []

    #     for subject in subjects
    #         println("$(subject.step). $(subject.max_score)")
    #         if (subject.max_score > max_score)
    #             max_score = subject.max_score
    #             max_moves = subject.max_moves
    #         end
    #     end
    # end
end

run()