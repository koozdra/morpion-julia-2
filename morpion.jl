import Dates
import Base.copy
using Random

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

        # count the number of empty points and record the last one
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

function eval_dna_exp(board, dna::Array{Int16,1})
    function dna_move_reducer(a, b)
        a_val = dna[dna_index(a)]
        b_val = dna[dna_index(b)]
        m = a_val == 0 ? rand(-200:0) : a_val
        n = b_val == 0 ? rand(-200:0) : b_val
        (m > n) ? a : b
    end

    eval_possible_move_reducer(board, dna_move_reducer)
end

function generate_dna_exp(moves)
    morpion_dna = zeros(Int16, 40 * 40 * 4)
    i = 0
    # l = length(moves)

    for move in moves
        # morpion_dna[dna_index(move)] = l - i + 1
        morpion_dna[dna_index(move)] = i + 1
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

function end_search(board_template, min_accept_score, index, moves)
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
    end_searched_index::Dict{UInt64,Bool}
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
    Subject(1, pool_index, Dict{UInt64,Bool}(), 0, [])
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

function build_move_line_key(move::Move)
    (x, y) = start_point(move)
    (x, y, move.direction)
end

function lines_hash(moves::Array{Move,1})
    hash(sort(map(build_move_line_key, moves)))
end

function get_q_key(state::Array{Move}, action::Move)
    lines_hash([state;[action]])
end

function store_q_value(state, action, value, q)
    q[get_q_key(state, action)] = value
end

function store_q_value(state_action, value, q)
    q[lines_hash(state_action)] = value
end

mutable struct Gym
    taken_moves::Array{Move}
    possible_moves::Array{Move}
    board::Array{UInt8,1}
end

function new_gym(board_template)
    Gym([], initial_moves(), copy(board_template))
end

function copy(gym::Gym)
    Gym(copy(gym.taken_moves), copy(gym.possible_moves), copy(gym.board))
end

function select_random_possible_move(gym::Gym)
    gym.possible_moves[rand(1:end)]
end



function select_possible_move_by_policy(q_table, state, possible_moves)
    # could be more efficient
    # println(possible_moves)
    shuffled_moves = shuffle(possible_moves)
    # println(shuffled_moves)
    # println()
    move = shuffled_moves[argmax(map(possible_move->get_q_value(q_table, get_q_key(state, possible_move)), shuffled_moves))]

    # println(move)
    # println()

    move
    
end

function select_possible_move_by_policy_e_greedy(q_table, state, possible_moves, epsilon)
    if (rand() < epsilon)
        possible_moves[rand(1:end)]
    else
        select_possible_move_by_policy(q_table, state, possible_moves)
    end
end

function step(gym::Gym, action::Move)
    make_move_on_board(gym.taken_moves, gym.board, gym.possible_moves, action)
    (gym.taken_moves, length(gym.possible_moves) == 0)
end

function step_moves(gym::Gym, moves::Array{Move,1})
    for move in moves
        step(gym, move)
    end
end

function step_randomely_to_end(gym::Gym)
    while length(gym.possible_moves) > 0
        step(gym, select_random_possible_move(gym))
    end
end

function get_q_value(q_table::Dict{UInt64,Float64}, q_key::UInt64)
    if (haskey(q_table, q_key))
        return q_table[q_key]
    end
    0
end

function partition_by(f, array)
    a = []
    b = []
    for i in array
        if f(i) 
            push!(a, i)
        else
            push!(b, i)
        end
    end
    (a, b)
end

function has_q_value(q_table, q_table_key)
    haskey(q_table, q_table_key)
end

function max_q_value_for_state(q_table, state, possible_moves)
    next_q_values = map(possible_move->get_q_value(q_table, get_q_key(state, possible_move)), possible_moves)
    max_next_q_value = maximum(next_q_values)
end

function estimate_value_of_move(q_table, gym, move)
    step(gym, move)
    # step_randomely_to_end(gym)
    while length(gym.possible_moves) > 0
        step(gym, select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves))
    end
    length(gym.taken_moves)
end

function set_eligibility(eligibility, q_key)
    eligibility[q_key] = 1
end

function get_eligibility(eligibility, q_key, default)
    if haskey(eligibility, q_key)
        eligibility[q_key]
    else
        default
    end
end

function decay_eligibility(eligibility, lambda, delta)
    for key in keys(eligibility)
        eligibility[key] = eligibility[key] * lambda * delta
    end
end

function mc_tree_visit_node(mc_tree, mc_tree_key, score)
    # tree_visits, tree_score = if haskey(mc_tree, mc_tree_key)
    #     mc_tree[mc_tree_key]
    # else
    #     (1, score)
    # end

    # average = tree_score + (1 / tree_visits) * (score - tree_score)

    # mc_tree[mc_tree_key] = (tree_visits + 1, average)
    new_visits, new_score = if haskey(mc_tree, mc_tree_key)
        tree_visits, tree_score = mc_tree[mc_tree_key]
        average = tree_score + (1 / (tree_visits + 1)) * (score - tree_score)
        (tree_visits + 1, average)
    else
        (1, score)
    end

    mc_tree[mc_tree_key] = (new_visits, new_score)
end

function mc_tree_contains_key(mc_tree, key)
    haskey(mc_tree, key)
end

function mc_tree_state_key(moves)
    lines_hash(moves)
end

function mc_tree_state_key(moves, move)
    lines_hash([moves; move])
end

function mc_tree_rank_possible_move(mc_tree, moves, move)
    mc_tree_key = mc_tree_state_key(moves)
    child_mc_tree_key = mc_tree_state_key(moves, move)
    if haskey(mc_tree, child_mc_tree_key)
        (visits, score) = mc_tree[mc_tree_key]
        (child_visits, child_score) = mc_tree[child_mc_tree_key]

        (child_score / 200) + sqrt(2 * log(visits) / child_visits)
    else
        # could be an issue if actual scores get this large (maybe this should be a negative number?)
        rand(11111:99999)
    end
end

function mc_tree_backup_reward(mc_tree, mc_tree_key_path)
end

function mc_tree_select_possible_move(mc_tree, gym) 
    max_index = argmax(map(possible_move->mc_tree_rank_possible_move(mc_tree, gym.taken_moves, possible_move), gym.possible_moves))
    gym.possible_moves[max_index]
end

function mc_tree_visit(mc_tree, gym)
    mc_tree_visit(mc_tree, gym, [])
end

function mc_tree_visit(mc_tree, gym, visited_mc_tree_keys)
    if isempty(gym.possible_moves)

        episode_score = length(gym.taken_moves)
        for mc_tree_key in visited_mc_tree_keys
            mc_tree_visit_node(mc_tree, mc_tree_key, episode_score)
        end

        return (visited_mc_tree_keys, episode_score)
    end


    move = mc_tree_select_possible_move(mc_tree, gym)

    current_mc_tree_key = mc_tree_state_key(gym.taken_moves)
    push!(visited_mc_tree_keys, current_mc_tree_key)

    is_move_visited = mc_tree_contains_key(mc_tree, mc_tree_state_key(gym.taken_moves, move))

    if !is_move_visited
        # eval_gym = copy(gym)

        step(gym, move)

        next_mc_tree_key = mc_tree_state_key(gym.taken_moves)
        push!(visited_mc_tree_keys, next_mc_tree_key)

        # println("E move: $move")

        step_randomely_to_end(gym)

        episode_score = length(gym.taken_moves)

        for mc_tree_key in visited_mc_tree_keys
            mc_tree_visit_node(mc_tree, mc_tree_key, episode_score)
        end
        
        return (visited_mc_tree_keys, episode_score)
    end

    # move = mc_tree_select_possible_move(mc_tree, gym)
    # println("V move: $move")
    step(gym, move)

    mc_tree_visit(mc_tree, gym, visited_mc_tree_keys)      

end

function mc_tree_search(mc_tree, board_template, test_moves, iterations)
    start_gym = new_gym(board_template)
    step_moves(start_gym, test_moves)

    for i in 1:iterations
        gym = copy(start_gym)
        mc_tree_visit(mc_tree, gym)
    end
end

function mc_tree_search_index(mc_tree, board_template, test_moves, iterations, min_accept_score)
    start_gym = new_gym(board_template)
    step_moves(start_gym, test_moves)
    index = Dict()

    for i in 1:iterations
        gym = copy(start_gym)
        mc_tree_visit(mc_tree, gym)
        episode_score = length(gym.taken_moves)
        episode_hash = points_hash(gym.taken_moves)
        
        if episode_score >= min_accept_score
            index[episode_hash] = (gym.taken_moves, 0)
        end
    end

    index
end

function modification_dna_search(moves, visits, iterations, board_template)
    results = []
    score = length(moves)
    for i in 1:iterations
        current_dna = generate_dna_exp(moves)
        current_visits = visits + (i - 1)
        if div(current_visits, score) % 4 == 0
            for i in 0:2
                # current_dna[dna_index(moves[rand(1:end)])] = -rand()
                current_dna[dna_index(moves[rand(1:end)])] = -200
            end
        elseif div(current_visits, score) % 4 == 1
            for i in 0:1
                # current_dna[dna_index(moves[rand(1:end)])] = -rand()
                current_dna[dna_index(moves[rand(1:end)])] = -200
            end
            
        elseif div(current_visits, score) % 4 == 2
            # current_dna[dna_index(moves[rand(1:end)])] = -rand()
            current_dna[dna_index(moves[rand(1:end)])] = -200
            
        else
            move_index = current_visits % score + 1
            # current_dna[dna_index(moves[move_index])] = -rand()
            current_dna[dna_index(moves[move_index])] = -200
        end

        # for i in 0:1
        # current_dna[dna_index(moves[rand(1:end)])] = -rand()
        # end

        # eval_moves = eval_dna(copy(board_template), current_dna)
        eval_moves = eval_dna_exp(copy(board_template), current_dna)

        push!(results, eval_moves)
    end

    results
end

function new_end_search(moves, min_accept_score, board_template, iterations, max_new_found)
    score = length(moves)
    index = Dict()
    gyms = []

### do this as one loop, since iteratons 1 works well

    for i in trunc(Int, score / 2):(score - 1)
        partial_moves = moves[1:i]
        gym = new_gym(board_template)
        step_moves(gym, partial_moves)

        push!(gyms, gym)
        # println(length(gym.taken_moves))
    end

    
    new_found_misses = 0

    while new_found_misses < iterations && length(index) < max_new_found
        new_found = false
        for i in iterations
            for gym in gyms
                eval_gym = copy(gym)
                step_randomely_to_end(eval_gym)
                eval_score = length(eval_gym.taken_moves)

                if eval_score >= min_accept_score
                    eval_hash = points_hash(eval_gym.taken_moves)
                    is_new = !haskey(index, eval_hash)
                    if is_new
                        index[eval_hash] = (eval_gym.taken_moves, 0)
                        new_found = true
                        new_found_misses = 0
                    end
                end
            end
        end

        if !new_found
            new_found_misses += 1
        end
    end

    index
end

function run() 
    board_template = generate_initial_board()


    # for i in 1:10

    #     start_moves = Move[Move(2, 0, 1, 0), Move(9, 2, 3, 0), Move(0, 2, 3, 0), Move(10, 3, 1, -4), Move(6, 4, 3, -4), Move(2, 2, 0, -2), Move(8, 5, 0, -2), Move(3, 5, 3, 0), Move(3, 4, 3, -3), Move(4, 6, 1, -4), Move(2, 4, 2, -2), Move(2, 5, 3, -3), Move(6, 5, 3, -1), Move(5, 6, 1, 0), Move(7, 4, 0, -2), Move(5, 2, 2, 0), Move(4, 2, 1, -2), Move(4, 3, 0, -2), Move(5, 3, 1, -3), Move(7, 5, 2, -3), Move(1, 5, 0, -1), Move(4, 5, 1, -4), Move(4, 4, 3, -2), Move(5, 4, 1, -2), Move(5, 1, 3, -1), Move(5, 5, 1, -1), Move(8, 2, 0, -4), Move(7, 1, 0, -4), Move(4, 1, 1, -1), Move(10, 4, 2, -4), Move(7, 7, 0, -1), Move(1, 2, 2, 0), Move(1, 4, 0, -1), Move(1, 7, 3, -4), Move(-1, 2, 2, 0), Move(-1, 4, 1, 0), Move(-2, 2, 1, 0), Move(-1, 3, 2, -1), Move(-2, 3, 1, 0), Move(2, 7, 2, -4), Move(2, 1, 0, -3), Move(1, 0, 2, 0), Move(1, 1, 2, 0), Move(3, -1, 0, -4), Move(2, -2, 2, 0), Move(2, -1, 3, -1), Move(1, -2, 2, 0), Move(1, -1, 3, -1), Move(0, 1, 0, -2), Move(-1, 1, 1, 0), Move(-1, 0, 3, 0), Move(0, 0, 0, -2), Move(-2, 0, 1, 0), Move(0, -2, 2, 0), Move(0, -1, 3, -1), Move(4, -1, 1, -4), Move(4, -2, 3, 0), Move(3, -2, 1, -3), Move(3, -3, 3, 0), Move(2, -3, 2, 0), Move(-2, 1, 0, 0), Move(-2, -1, 3, 0), Move(-3, -2, 2, 0), Move(2, 9, 1, 0), Move(7, 2, 3, -1), Move(10, 5, 2, -4), Move(10, 2, 1, -4), Move(10, 6, 3, -4), Move(8, 4, 2, -2), Move(5, 7, 0, 0), Move(5, 8, 3, -4), Move(11, 4, 1, -4), Move(4, 7, 1, -3), Move(8, 7, 3, -4), Move(7, 8, 0, 0), Move(9, 8, 2, -4), Move(8, 8, 1, -3), Move(9, 7, 1, -4), Move(9, 9, 2, -4), Move(8, 1, 0, -4), Move(12, 5, 2, -4), Move(11, 5, 1, -3), Move(9, 10, 3, -4), Move(8, 9, 2, -3), Move(1, 10, 0, 0), Move(7, 9, 3, -4), Move(6, 10, 0, 0), Move(4, 8, 2, -2), Move(8, 10, 2, -4), Move(4, 10, 3, -4), Move(2, 8, 2, -2), Move(10, 9, 1, -4), Move(8, 11, 3, -4), Move(1, 8, 1, 0), Move(0, 9, 0, 0), Move(2, 10, 3, -4), Move(1, 11, 0, 0), Move(1, 9, 3, -2), Move(0, 10, 0, 0), Move(3, 10, 1, -3), Move(2, 11, 0, 0), Move(7, 10, 2, -3), Move(5, 10, 1, -1), Move(6, 11, 2, -4), Move(5, 12, 0, 0), Move(5, 11, 3, -3), Move(6, 12, 3, -4), Move(4, 11, 2, -3), Move(3, 12, 0, 0), Move(4, 13, 2, -4), Move(3, 11, 1, -2), Move(2, 12, 0, 0), Move(3, 13, 3, -4), Move(-1, 9, 2, 0), Move(0, 8, 0, -1), Move(4, 12, 2, -4), Move(2, 14, 0, 0), Move(2, 13, 3, -3), Move(0, 7, 3, -1), Move(-2, 9, 1, 0), Move(-1, 8, 0, -1), Move(4, 14, 3, -4), Move(7, 12, 1, -4), Move(6, 13, 0, 0), Move(5, 13, 1, -3), Move(7, 11, 0, -2), Move(9, 11, 1, -4), Move(7, 13, 3, -4), Move(8, 14, 2, -4)]

    #     result = new_end_search(start_moves, length(start_moves) - 6, board_template, 1)
        
    #     println(length(result))
    # end

    # readline()
    
    
    gym = new_gym(board_template)
    step_randomely_to_end(gym)

    pool_index = Dict()

    for i in 1:100
        start_searchy = (gym.taken_moves, 0)
        start_searchy_hash = points_hash(gym.taken_moves)
        pool_index[start_searchy_hash] = start_searchy
    end

    pool_keys = collect(keys(pool_index))

    end_searched_index = Dict()

    max_score = length(gym.taken_moves)
    max_moves = 0
    pool_score = max_score

    trip_time = Dates.now()

    end_search_interval = 100

    iteration = 1
    total_evaluations = 0
    min_accept_default = 1

    min_accept_offset = min_accept_default

    inactivity_counter = 0
    improvements = 0

    while true

        # min_accept_offset =  trunc(Int, total_evaluations / 1000000)

        if inactivity_counter > 100000
            
            min_accept_offset += 1
            inactivity_counter = 0
            improvements = 0

            end_searched_index = Dict()

            println()
            println("dropping: $min_accept_offset")
            println()
        end

        if improvements >= 100
            improvements = 0

            min_accept_offset = max(min_accept_offset - 1, min_accept_default)

            # min_accept_offset = 1
            # end_searched_index = Dict()
            # println("reseting end_search_index")

            println()
            println("rising: $min_accept_offset")
            println()
        end

        min_accept_score = max_score - min_accept_offset
        
        current_index = (iteration % length(pool_keys)) + 1
        current_pool_key = pool_keys[current_index]

        (current_moves, current_visits) = pool_index[current_pool_key]
        current_score = length(current_moves)

        if current_score < min_accept_score
            deleteat!(pool_keys, current_index)
            delete!(pool_index, current_pool_key)
            # println(" - $current_score")
            
        else
            times = (min_accept_offset - (max_score - current_score)) + 1
            # times = times * times
            # times = times * 100
            # times = [1, 6][times]
            # times = [1, 1, 1, 1, 2][times]

            # times = 1
            # if current_score == max_score
            #     times = 3
            # end
            # if current_score == max_score - 1
            #     times = 2
            # end

            # times = [1, 1, 1, 1, 1, 1, 1, 10, 20, 50, 100][times]
            # n = 2
            # times = times * 2
            # times =

            modification_search_results = modification_dna_search(current_moves, current_visits, times, board_template)
            num_visits = times

            total_evaluations += num_visits

            for eval_moves in modification_search_results

                eval_score = length(eval_moves)
                eval_moves_hash = points_hash(eval_moves)
                is_new = !haskey(pool_index, eval_moves_hash)

                if is_new
                    
                    
                    
                    if eval_score >= min_accept_score
                        pool_size = length(pool_keys)
                        println("$total_evaluations. $current_score ($current_visits) -> $eval_score ($max_score, $pool_size, ($inactivity_counter, $min_accept_offset, $improvements))")

                        push!(pool_keys, eval_moves_hash)
                        pool_index[eval_moves_hash] = (eval_moves, 0)

                        # min_accept_offset = max(min(max_score - eval_score, min_accept_offset), 0)

                        # min_accept_offset += eval_score - min_accept_score

                        # pool_moves, pool_visits = pool_index[current_pool_key]
                        # pool_index[current_pool_key] = (current_moves, 0)

                        
                    end

                    if eval_score > min_accept_score
                        improvements += 1
                        
                    end

                    if eval_score >= min_accept_score
                        inactivity_counter = 0
                    end

                    # if eval_score > current_score
                    #     pool_size = length(pool_keys)
                    #     println("$total_evaluations. $current_score ($current_visits) => $eval_score ($max_score, $pool_size)")
                    # elseif eval_score >= current_score
                    #     pool_size = length(pool_keys)
                    #     println("$total_evaluations. $current_score ($current_visits) -> $eval_score ($max_score, $pool_size)")
                    # end

                    if eval_score > max_score
                        println("$total_evaluations. $current_score ($current_visits) ==> $eval_score")
                        # println(eval_moves)
                        max_score = eval_score
                        max_moves = eval_moves

                        min_accept_offset = min_accept_default
                        improvements = 0
                    end
                else
                    pool_moves, pool_visits = pool_index[eval_moves_hash]
                    pool_index[eval_moves_hash] = (eval_moves, pool_visits)
                end

            end

            (pool_moves, pool_visits) = pool_index[current_pool_key]
            pool_index[current_pool_key] = (pool_moves, pool_visits + num_visits)

            # if !haskey(end_searched_index, current_pool_key) && current_score >= 100 && iteration % 200 == 0

            if max_score >= 100 && iteration % end_search_interval == 0
                
                pool_key_value_pairs = collect(pool_index)
                endy_moves = []
                # (endy_key, (endy_moves, endy_visits)) =  pool_key_value_pairs[1]
                # endy_score = length(endy_moves)
                endy_score = 0
                endy_visits = 9999999
                endy_key = 0

                for (key, (moves, visits)) in pool_key_value_pairs
                    score = length(moves)

                    if !haskey(end_searched_index, key)


                        if (score == endy_score && visits <= endy_visits) ||
                            score > endy_score
                        
                            endy_moves = moves
                            endy_visits = visits
                            endy_score = score
                            endy_key = key
                        end
                    end

                end

                if endy_score >= min_accept_score
                    
                    result = new_end_search(endy_moves, min_accept_score, board_template, 10, 200)

                    println(" ES:: $endy_score (found: $(length(result))) ")

                    for (pair_hash, pair_value) in collect(result)
                        if !haskey(pool_index, pair_hash)
                            push!(pool_keys, pair_hash)
                            pool_index[pair_hash] = pair_value

                            (moves, visits) = pair_value

                            score = length(moves)

                            if score > max_score
                                println("$total_evaluations. $endy_score ($endy_visits) ==> $score")
                                # println(eval_moves)
                                max_score = score
                                max_moves = moves
                                min_accept_offset = min_accept_default
                                improvements = 0
                            end


                            if score > min_accept_score
                                improvements += 1
                            end

                            if score >= min_accept_score
                                inactivity_counter = 0
                            end

                            println(" es. $endy_score -> $(length(moves))")

                            # pool_moves, pool_visits = pool_index[current_pool_key]
                            # pool_index[current_pool_key] = (current_moves, 0)
                            
                            
                        end

                        end_searched_index[pair_hash] = true
                    end

                    

                    end_searched_index[endy_key] = true
                end
            end

            # if iteration % 1000000 == 0
            #     min_accept_offset = max(min_accept_offset - 1, 0)

            #     # min_accept_offset = 0
            #     println()
            #     println("rising: $min_accept_offset")
            #     println()
            # end

            # if iteration % 1000000 == 0
            #     min_accept_offset = max(min_accept_offset - 1, 0)

            #     # min_accept_offset = 1
            #     end_searched_index = Dict()
            #     println("reseting end_search_index")
            # end


            iteration += 1
            inactivity_counter += 1

            if iteration % 1000000 == 0
                println(max_score)
                println(max_moves)
            end

        end

    end

    # for iteration in 1:100000000

    #     if iteration % 10000 == 0
    #         current_time = Dates.now()
    #         println("$iteration. $max_score $(current_time - trip_time) $(length(pool))")
    #         trip_time = Dates.now()
    #     end
    #     # current_index = rand(1:length(pool))
    #     current_index = (iteration % length(pool)) + 1

    #     (current_moves, current_visits) = pool[current_index]
    #     current_score = length(current_moves)

    #     if current_score > max_score

    #         # pool = [(current_score, 0)]
    #         # pool_index = Dict()
    #         # pool_index[eval_moves_hash] = 1
    
    #         max_score = current_score
    
    #         # println("$iteration. $current_score => $eval_score")
    #     end

    #     min_accept_offset = 5
    #     min_accept_score = max_score - min_accept_offset
    #     times = (min_accept_offset - (max_score - current_score)) + 1
    #     times = times * times

        

        
    #     modification_search_results = modification_dna_search(current_moves, current_visits, times, board_template)

    #     for eval_moves in modification_search_results

    #         eval_score = length(eval_moves)
    #         eval_moves_hash = lines_hash(eval_moves)
    #         is_new = !haskey(pool_index, eval_moves_hash)


    #         if is_new 
    #             if eval_score >= min_accept_score && 
    #                 push!(pool, (eval_moves, 0))
    #                 pool_index[eval_moves_hash] = length(pool)
    #             end
    #         else
    #             pool_index_position = pool_index[eval_moves_hash]
    #             (pool_moves, pool_visits) = pool[pool_index_position]
    #             pool[pool_index_position] = (eval_moves, pool_visits)
    #         end

    #     end

    #     # for i in 1:times

    #     #     println("$iteration. $current_score $i")

            
        

    #     #     current_dna = generate_dna(current_moves)

    #     #     move_1_index = current_visits % length(current_moves) + 1
    #     #     move_2_index = trunc(Int, current_visits / length(current_moves)) % length(current_moves) + 1
    #     #     current_dna[dna_index(current_moves[move_1_index])] = -rand()
    #     #     current_dna[dna_index(current_moves[move_2_index])] = -rand()



    #     #     eval_moves = eval_dna(copy(board_template), current_dna)
    #     #     eval_score = length(eval_moves)
    #     #     eval_moves_hash = lines_hash(eval_moves)
        
        

    #     #     if eval_score > max_score

    #     #         pool = [(eval_moves, 0)]
    #     #         pool_index = Dict()
    #     #         pool_index[eval_moves_hash] = 1

    #     #         max_score = eval_score

    #     #         println("$iteration. $current_score => $eval_score")
    #     #     else
    #     #         pool[current_index] = (current_moves, current_visits + 1)
           

    #     #         if eval_score >= min_accept_score

    #     #             is_new = !haskey(pool_index, eval_moves_hash)

    #     #             pool_size = length(pool)

    #     #             if is_new 
                
                
    #     #                 push!(pool, (eval_moves, 0))
    #     #                 pool_index[eval_moves_hash] = length(pool)

    #     #                 # println("$iteration. $current_score ($current_visits) -> $eval_score $pool_size")
                    
    
    #     #             else
    #     #                 pool_index_position = pool_index[eval_moves_hash]
    #     #                 (pool_moves, pool_visits) = pool[pool_index_position]
    #     #                 pool[pool_index_position] = (eval_moves, pool_visits)

    #     #             # println("$iteration. $current_score == $eval_score")
    
    #     #             end
    #     #         end
    #     #     end
    #     # end

    #     # if current_score < min_accept_score 
    #     #     deleteat!(pool, current_index)

    #     # # todo delete from index also

    #     #     println(" - $current_score")

    #     # end
    # end




    # state_hash -> (visits, score)
    # mc_tree = Dict{UInt64,Tuple{Int64,Float64}}()

    # # 129
    # # start_moves = Move[Move(2, 0, 1, 0), Move(9, 2, 3, 0), Move(0, 2, 3, 0), Move(10, 3, 1, -4), Move(6, 4, 3, -4), Move(2, 2, 0, -2), Move(8, 5, 0, -2), Move(3, 5, 3, 0), Move(3, 4, 3, -3), Move(4, 6, 1, -4), Move(2, 4, 2, -2), Move(2, 5, 3, -3), Move(6, 5, 3, -1), Move(5, 6, 1, 0), Move(7, 4, 0, -2), Move(5, 2, 2, 0), Move(4, 2, 1, -2), Move(4, 3, 0, -2), Move(5, 3, 1, -3), Move(7, 5, 2, -3), Move(1, 5, 0, -1), Move(4, 5, 1, -4), Move(4, 4, 3, -2), Move(5, 4, 1, -2), Move(5, 1, 3, -1), Move(5, 5, 1, -1), Move(8, 2, 0, -4), Move(7, 1, 0, -4), Move(4, 1, 1, -1), Move(10, 4, 2, -4), Move(7, 7, 0, -1), Move(1, 2, 2, 0), Move(1, 4, 0, -1), Move(1, 7, 3, -4), Move(-1, 2, 2, 0), Move(-1, 4, 1, 0), Move(-2, 2, 1, 0), Move(-1, 3, 2, -1), Move(-2, 3, 1, 0), Move(2, 7, 2, -4), Move(2, 1, 0, -3), Move(1, 0, 2, 0), Move(1, 1, 2, 0), Move(3, -1, 0, -4), Move(2, -2, 2, 0), Move(2, -1, 3, -1), Move(1, -2, 2, 0), Move(1, -1, 3, -1), Move(0, 1, 0, -2), Move(-1, 1, 1, 0), Move(-1, 0, 3, 0), Move(0, 0, 0, -2), Move(-2, 0, 1, 0), Move(0, -2, 2, 0), Move(0, -1, 3, -1), Move(4, -1, 1, -4), Move(4, -2, 3, 0), Move(3, -2, 1, -3), Move(3, -3, 3, 0), Move(2, -3, 2, 0), Move(-2, 1, 0, 0), Move(-2, -1, 3, 0), Move(-3, -2, 2, 0), Move(2, 9, 1, 0), Move(7, 2, 3, -1), Move(10, 5, 2, -4), Move(10, 2, 1, -4), Move(10, 6, 3, -4), Move(8, 4, 2, -2), Move(5, 7, 0, 0), Move(5, 8, 3, -4), Move(11, 4, 1, -4), Move(4, 7, 1, -3), Move(8, 7, 3, -4), Move(7, 8, 0, 0), Move(9, 8, 2, -4), Move(8, 8, 1, -3), Move(9, 7, 1, -4), Move(9, 9, 2, -4), Move(8, 1, 0, -4), Move(12, 5, 2, -4), Move(11, 5, 1, -3), Move(9, 10, 3, -4), Move(8, 9, 2, -3), Move(1, 10, 0, 0), Move(7, 9, 3, -4), Move(6, 10, 0, 0), Move(4, 8, 2, -2), Move(8, 10, 2, -4), Move(4, 10, 3, -4), Move(2, 8, 2, -2), Move(10, 9, 1, -4), Move(8, 11, 3, -4), Move(1, 8, 1, 0), Move(0, 9, 0, 0), Move(2, 10, 3, -4), Move(1, 11, 0, 0), Move(1, 9, 3, -2), Move(0, 10, 0, 0), Move(3, 10, 1, -3), Move(2, 11, 0, 0), Move(7, 10, 2, -3), Move(5, 10, 1, -1), Move(6, 11, 2, -4), Move(5, 12, 0, 0), Move(5, 11, 3, -3), Move(6, 12, 3, -4), Move(4, 11, 2, -3), Move(3, 12, 0, 0), Move(4, 13, 2, -4), Move(3, 11, 1, -2), Move(2, 12, 0, 0), Move(3, 13, 3, -4), Move(-1, 9, 2, 0), Move(0, 8, 0, -1), Move(4, 12, 2, -4), Move(2, 14, 0, 0), Move(2, 13, 3, -3), Move(0, 7, 3, -1), Move(-2, 9, 1, 0), Move(-1, 8, 0, -1), Move(4, 14, 3, -4), Move(7, 12, 1, -4), Move(6, 13, 0, 0), Move(5, 13, 1, -3), Move(7, 11, 0, -2), Move(9, 11, 1, -4), Move(7, 13, 3, -4), Move(8, 14, 2, -4)]


    # start_moves = Move[Move(2, 2, 0, -2), Move(6, 4, 3, -4), Move(2, 0, 1, 0), Move(7, 9, 1, -4), Move(6, 10, 3, -4), Move(4, 6, 1, -4), Move(0, 2, 3, 0), Move(10, 6, 1, -4), Move(3, -1, 3, 0), Move(5, 1, 2, -2), Move(3, 5, 3, 0), Move(2, 4, 2, -2), Move(2, 5, 3, -3), Move(-1, 3, 1, 0), Move(1, 1, 0, -2), Move(9, 2, 3, 0), Move(4, 2, 0, -2), Move(5, 3, 2, -3), Move(4, 4, 0, -2), Move(5, 5, 2, -4), Move(5, 2, 1, -3), Move(5, 4, 3, -4), Move(4, 3, 1, -1), Move(2, 8, 0, 0), Move(4, 1, 3, -1), Move(1, 4, 0, -1), Move(-1, 2, 2, 0), Move(2, 1, 1, 0), Move(1, 0, 2, 0), Move(1, 2, 3, -2), Move(-2, 2, 1, 0), Move(1, 5, 2, -3), Move(-1, 5, 1, 0), Move(-1, 4, 0, 0), Move(-1, 6, 3, -4), Move(1, 7, 2, -2), Move(1, 8, 3, -4), Move(7, 2, 2, -2), Move(3, 4, 1, -3), Move(2, -1, 2, 0), Move(4, 5, 0, -1), Move(4, 8, 2, -2), Move(5, 8, 1, -4), Move(3, 10, 0, 0), Move(0, 7, 0, 0), Move(2, 9, 2, -3), Move(5, 6, 2, -4), Move(5, 7, 3, -3), Move(2, 10, 0, 0), Move(2, 7, 3, -1), Move(4, 7, 1, -4), Move(7, 10, 2, -4), Move(8, 10, 2, -4), Move(4, 10, 3, -4), Move(6, 5, 0, -4), Move(7, 5, 1, -4), Move(7, 4, 3, -2), Move(8, 4, 1, -3), Move(10, 1, 0, -4), Move(11, 7, 2, -4), Move(7, 7, 0, -3), Move(7, 8, 3, -2), Move(8, 7, 1, -4), Move(5, 10, 0, 0), Move(9, 10, 1, -4), Move(6, 11, 2, -4), Move(1, 10, 1, 0), Move(8, 9, 2, -3), Move(8, 8, 3, -2), Move(9, 8, 1, -4), Move(9, 9, 2, -4), Move(10, 9, 2, -4), Move(9, 7, 3, -1), Move(10, 7, 0, -4), Move(10, 8, 2, -4), Move(10, 5, 3, 0), Move(11, 9, 1, -4), Move(12, 7, 1, -4), Move(12, 6, 0, -4), Move(-2, 3, 2, 0), Move(0, 1, 0, -2), Move(11, 5, 0, -4), Move(8, 5, 1, -1), Move(8, 2, 3, 0), Move(10, 2, 1, -4), Move(11, 8, 2, -4), Move(10, 4, 2, -2), Move(13, 6, 0, -4), Move(11, 6, 3, -1), Move(14, 6, 1, -4), Move(13, 8, 2, -4), Move(12, 8, 1, -3), Move(10, 3, 3, -2), Move(11, 3, 1, -4), Move(11, 2, 0, -4), Move(12, 2, 0, -4), Move(11, 1, 0, -4), Move(11, 4, 3, -3), Move(12, 5, 2, -3), Move(12, 4, 3, 0), Move(13, 5, 2, -3), Move(13, 4, 1, -4), Move(14, 3, 0, -4), Move(13, 7, 3, -3), Move(15, 5, 0, -4), Move(14, 5, 1, -3), Move(12, 3, 2, -2), Move(13, 2, 0, -4), Move(14, 2, 1, -4), Move(14, 4, 3, -2), Move(13, 3, 2, -2), Move(15, 3, 1, -4), Move(16, 2, 0, -4), Move(15, 1, 0, -4), Move(2, -2, 3, 0)]

    # start_score = length(start_moves)
    # test_moves = start_moves[1:80]

    # gym = new_gym(board_template)
    # step_moves(gym, test_moves)

    # while !isempty(gym.possible_moves)
    #     mc_tree_search(mc_tree, board_template, gym.taken_moves, 10000)

    #     println()
    #     for possible_move in gym.possible_moves
    #         mc_tree_key = mc_tree_state_key(gym.taken_moves, possible_move)
    #         if haskey(mc_tree, mc_tree_key)
    #             println("$possible_move: $(mc_tree[mc_tree_key])")
    #         end
    #     end
        
    #     move = gym.possible_moves[argmax(map(possible_move->mc_tree[mc_tree_state_key(gym.taken_moves, possible_move)], gym.possible_moves))]

    #     println("chosen move: $move ($(length(gym.taken_moves)))")
    #     step(gym, move)

    # end
    

    

    # println(mc_tree)

    
    
    # iteration = 0
    # while true
    
    #     eval_gym = copy(gym)
    #     step_randomely_to_end(eval_gym)
    #     start_score = length(start_moves)
    #     eval_score = length(eval_gym.taken_moves)
        

    #     println("$iteration. $start_score -> $eval_score")

    #     iteration += 1
    # end
    
    
    # dimitri

    
    # current_moves = random_completion(copy(board_template))
    # current_moves = Move[Move(2, 9, 1, 0), Move(6, 10, 3, -4), Move(4, 8, 2, -2), Move(3, 10, 3, -4), Move(5, 8, 0, -2), Move(7, 8, 1, -4), Move(7, 7, 0, -2), Move(5, 6, 1, 0), Move(-1, 6, 1, 0), Move(9, 7, 3, -4), Move(1, 4, 0, -2), Move(2, 7, 2, -2), Move(0, 7, 3, -4), Move(2, 2, 0, -2), Move(10, 3, 1, -4), Move(1, 8, 2, -2), Move(4, 3, 1, -4), Move(6, 4, 3, -4), Move(3, -1, 3, 0), Move(5, 1, 2, -2), Move(2, 0, 1, 0), Move(7, 2, 2, -2)]
    # max_moves = current_moves
    # max_score = length(max_moves)
    # step = 0

    # # start_moves_points_hash = points_hash(start_moves)
    # # Dict(start_moves_points_hash => (start_moves, 0, 0))

    # current_moves_points_hash = points_hash(current_moves)
    # pool_index = Dict(current_moves_points_hash => current_moves)

    # println(current_moves)

    # trip_time = Dates.now()

    # while true

    #     # current_moves = collect(values(pool_index))[(step % length(pool_index)) + 1]
    #     current_moves = collect(values(pool_index))[rand(1:end)]
    #     current_score = length(current_moves)

    #     current_dna = generate_dna(current_moves)

    #     # modification: one random
    #     # for i in 0:1
    #     #     current_dna[dna_index(current_moves[rand(1:end)])] = -rand()
    #     # end

    #     # modification: one random
    #     # for i in 0:2
    #     #     current_dna[dna_index(current_moves[rand(1:end)])] = -rand()
    #     # end

    #     # modification: one random
    #     # for i in 0:3
    #     #     current_dna[dna_index(current_moves[rand(1:end)])] = -rand()
    #     # end

    #     # modification: ascend with step
    #     # current_dna[dna_index(current_moves[step % length(current_moves) + 1])] = -rand()

    #     # modification: segment offset pairs
    #     move_1_index = step % length(current_moves) + 1
    #     move_2_index = trunc(Int, step / length(current_moves)) % length(current_moves) + 1
    #     current_dna[dna_index(current_moves[move_1_index])] = -rand()
    #     current_dna[dna_index(current_moves[move_2_index])] = -rand()




    #     eval_moves = eval_dna(copy(board_template), current_dna)
    #     eval_score = length(eval_moves)
    #     eval_moves_hash = lines_hash(eval_moves)

    #     is_in_index = haskey(pool_index, eval_moves_hash)

    #     if is_in_index
    #         pool_index[eval_moves_hash] = eval_moves
    #     end

    #     # println("$step. $current_score -> $eval_score")

    #     if eval_score > max_score
    #         println("$step. $eval_score")
    #         println(eval_moves)
    #         pool_index = Dict() 
    #     end

    #     if eval_score >= max_score && !is_in_index
    #         pool_index[eval_moves_hash] = eval_moves
    #     end

    #     if eval_score >= max_score
    #         max_score = eval_score
    #         max_move = eval_moves
    #         # current_moves = eval_moves
    #     end

    #     if step % 10000 == 0
    #         current_time = Dates.now()
    #         println("$step. $max_score $(current_time - trip_time) $(length(pool_index))")
    #         trip_time = Dates.now()
    #     end

        


        

    #     step += 1
    # end


    # use a single policy
    #  not enough exploration because alternate moves to the explore move
    #  are not rearranged
    # dna = rand(40 * 40 * 4)
    # step = 0

    # while true

    #     dna_moves = eval_dna(copy(board_template), dna)
    #     dna_score = length(dna_moves)

    #     dna_move = dna_moves[rand(1:end)]
    #     dna_move_key = dna_index(dna_move)
    #     dna_move_value = dna[dna_move_key]

    #     dna[dna_move_key] = rand()
    #     # dna[dna_move_key] = 0
    #     eval_dna_moves = eval_dna(copy(board_template), dna)
    #     eval_dna_score = length(eval_dna_moves)

    #     # println(dna_score)
    #     # println(eval_dna_score)

    #     if eval_dna_score < dna_score
    #         dna[dna_move_key] = dna_move_value
    #     end

    #     if eval_dna_score > dna_score
    #         println("$step. $eval_dna_score")
    #     end

    #     eval_dna_moves = eval_dna(copy(board_template), dna)
    #     eval_dna_score = length(eval_dna_moves)
    #     # println(eval_dna_score)

    #     step += 1

    # end


    # q_table = Dict{UInt64,Float64}()
    
    # # mc_tree = Dict{UInt64,(UInt64, Float64)}()

    # gym = new_gym(board_template)
    # state = gym.taken_moves

    # discount = 1
    # learning_rate = 1
    # num_episodes = 1000000

    # max_score = 0

    
    # explore_location = 0
    # episode_cumulative_reward = 0

    # eligibility = Dict{UInt64,Float64}()
    
    # for episode_num in 1:num_episodes

    #     gym = new_gym(board_template)
        
    #     explore_performed_in_episode = false
    #     episode_q_keys = []
    #     episode_counter = 1
        

    #     while length(gym.possible_moves) > 0
    #         state = gym.taken_moves


    #         action = if length(gym.taken_moves) == explore_location && !explore_performed_in_episode
    #             (moves_with_q_values, moves_without_q_values) = partition_by(possible_move->has_q_value(q_table, get_q_key(gym.taken_moves, possible_move)), gym.possible_moves)

    #             # println("decision point  $explore_location")
    #             # for move in moves_with_q_values  
    #             #     q_value = get_q_value(q_table, get_q_key(gym.taken_moves, move))
    #             #     println("$move $q_value")
    #             # end
    #             # println(moves_without_q_values)

    #             explore_location += 1 
    #             explore_performed_in_episode = true

    #             if length(moves_without_q_values) > 0
    #                 moves_without_q_values[rand(1:end)]
    #             else
    #                 moves_with_q_values[rand(1:end)]
    #             end
    #         else
    #             select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves)
    #         end

    #         # action = select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves)

            

    #         current_q_key = get_q_key(state, action)
    #         current_q_value = get_q_value(q_table, current_q_key)

    #         # println("$episode_counter. $action $current_q_value")

    #         push!(episode_q_keys, current_q_key)

    #         step(gym, action)

    #         if length(gym.possible_moves) > 0
    #             reward = 0
    #             max_next_q_value = max_q_value_for_state(q_table, gym.taken_moves, gym.possible_moves)
            
    #             q_table[current_q_key] = current_q_value + learning_rate * (reward + discount * max_next_q_value - current_q_value)
    #         else
    #             q_table[current_q_key] = length(gym.taken_moves)
    #         end

    #         episode_counter += 1
    #     end

    #     reward = 0

    #     for index in 1:(length(episode_q_keys) - 1)
    #         current_q_key = episode_q_keys[length(episode_q_keys) - index]
    #         current_q_value = get_q_value(q_table, current_q_key)

    #         next_q_key = episode_q_keys[length(episode_q_keys) - index + 1]
    #         next_q_value = get_q_value(q_table, next_q_key)
            
    #         new_q_value = current_q_value + learning_rate * (reward + discount * next_q_value - current_q_value)

    #         q_table[current_q_key] = new_q_value

    #         # println("$(current_q_key) $(current_q_value)  $next_q_key $next_q_value  $new_q_value")
    #     end

    #     episode_score = length(gym.taken_moves)

    #     max_score = max(max_score, episode_score)
    #     episode_cumulative_reward += episode_score
        
    #     if episode_num % 100 == 0
    #         println("$episode_num. $(episode_score) ($max_score,$episode_cumulative_reward)")
    #         episode_cumulative_reward = 0
    #     end

    #     if !explore_performed_in_episode
    #         explore_location = 0
    #     end
    #     # println(gym.taken_moves)
        

    #     # println()

    #     # for index in 1:length(episode_q_keys)
    #     #     q_key = episode_q_keys[index]
    #     #     q_value = get_q_value(q_table, q_key)
    #     #     println("$(q_key) $(q_value)")
    #     # end

    # end

    # println()
    # println(length(q_table))



    # discount = 0.995
    # learning_rate = 0.1
    # epsilon = 0.01

    # num_episodes = 100000
    # max_score = 20

    # # idea: only do one explore per episode, corresponding to n where n is incremented per episode. if n not used then reset to 0

    # for episode in 1:num_episodes

    #     # epsilon = 1 / max_score

    #     episode_q_keys = []
    #     gym = new_gym(board_template)
    #     # action = select_possible_move_by_policy_e_greedy(q_table, gym.taken_moves, gym.possible_moves, epsilon)
    #     while length(gym.possible_moves) > 0
    #         action = select_possible_move_by_policy_e_greedy(q_table, gym.taken_moves, gym.possible_moves, epsilon)

    #         current_q_key = get_q_key(gym.taken_moves, action)
    #         current_q_value = get_q_value(q_table, current_q_key)

    #         step(gym, action)

    #         reward = 0
    #         # reward = length(gym.taken_moves)

    #         if length(gym.possible_moves) > 0
                
    #             max_next_q_value = max_q_value_for_state(q_table, gym.taken_moves, gym.possible_moves)
                
    #             q_table[current_q_key] = current_q_value + learning_rate * (reward + discount * max_next_q_value - current_q_value)
    #         else

    #             q_table[current_q_key] = length(gym.taken_moves)
    #         end

            

    #         # reward = length(gym.taken_moves)

    #         # what should be done at the last step?
    #         # if length(gym.possible_moves) > 0

    #         #     next_action = select_possible_move_by_policy_e_greedy(q_table, gym.taken_moves, gym.possible_moves, epsilon)
    #         #     next_q_key = get_q_key(gym.taken_moves, next_action)
    #         #     next_q_value = get_q_value(q_table, next_q_key)
    #         #     # reward = 1
                

    #         #     # if next_q_value > 0 && current_q_value > 0
    #         #     # q_table[current_q_key] = current_q_value + learning_rate * (reward + discount * (next_q_value) - current_q_value)
    #         #     # else
    #         #     #     # q_table[current_q_key] = reward
    #         #     #     q_table[current_q_key] = reward
    #         #     # end

    #         #     action = next_action

    #         # else
    #         #     q_table[current_q_key] = learning_rate * reward
    #         # end



            
            
    #         # action = select_possible_move_by_policy_e_greedy(q_table, gym.taken_moves, gym.possible_moves, epsilon)

    #         # explore_score = episode % max_score

    #         # action = if explore_score == length(gym.taken_moves)
    #         #     # partition moves, pick unvisited, pick random
    #         #     select_random_possible_move(gym)
    #         # else
    #         #     select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves)
    #         # end

    #         # q_key = get_q_key(gym.taken_moves, action)
    #         # q_value = get_q_value(q_table, q_key)

    #         # push!(episode_q_keys, q_key)

    #         # step(gym, action)

    #         # if length(gym.possible_moves) > 0
    #             # reward = 0
    #             # max_next_q_value = max_q_value_for_state(q_table, gym.taken_moves, gym.possible_moves)
    #             # q_table[q_key] = q_value + learning_rate * (reward + discount * max_next_q_value - q_value)
    #         # end

    #     end
        
            
    #     # println(length(gym.taken_moves))
    #     # should this be reversed?

    #     # reward = length(gym.taken_moves)
    #     # for t_index in 1:(length(episode_q_keys) - 1)
    #     #     index = length(episode_q_keys) - t_index
    #     #     q_key = episode_q_keys[index]
    #     #     q_key_next = episode_q_keys[index + 1]
    #     #     q_value = get_q_value(q_table, q_key)
    #     #     q_value_next = get_q_value(q_table, q_key_next)
    #     #     q_table[q_key] = q_value + learning_rate * (reward + discount * q_value_next - q_value)
    #     # end
    #     episode_score = length(gym.taken_moves)

    #     max_score = max(max_score, episode_score)

        

    #     if (episode % 100 == 0)
    #         eval_gym = new_gym(board_template)
    #         while length(eval_gym.possible_moves) > 0
    #             action = select_possible_move_by_policy(q_table, eval_gym.taken_moves, eval_gym.possible_moves)
    #             step(eval_gym, action)
    #         end
    #         println("$episode. $episode_score $max_score ($(length(q_table))) greedy: $(length(eval_gym.taken_moves))")

    #         # println("$episode. $episode_score $max_score ($(length(q_table)))")
    #     end
    # end

    # gym = new_gym(board_template)
    # while length(gym.possible_moves) > 0
    #     action = select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves)
    #     current_q_key = get_q_key(gym.taken_moves, action)
    #     current_q_value = get_q_value(q_table, current_q_key)

    #     println("action: $action q: $current_q_value")
    #     step(gym, action)
    # end

    # println("greedy: $(length(gym.taken_moves))")
    # println(gym.taken_moves)


    # println("starting")
    # gym = new_gym(board_template)
    # for initial_move in initial_moves()
    #     current_q_key = get_q_key(gym.taken_moves, initial_move)
    #     current_q_value = get_q_value(q_table, current_q_key)
    #     println(" $initial_move $current_q_value")
    # end

    # Move(6, 4, 3, -4), Move(-1, 6, 1, 0)

    # num_episodes = 10000
    # max_score = 0
    

    # for episode in 1:num_episodes
    #     episode_complete = false
    #     gym = new_gym(board_template)

    #     while !episode_complete
            
    #         (moves_with_q_values, moves_without_q_values) = partition_by(possible_move->has_q_value(q_table, get_q_key(gym.taken_moves, possible_move)), gym.possible_moves)
            
    #         is_epsilon_explore = rand() < epsilon
    #         is_explore = is_epsilon_explore || length(moves_with_q_values) == 0

    #         # println(moves_with_q_values)
    #         # println(moves_without_q_values)
    #         if is_explore
        
    #             action = select_random_possible_move(gym)

    #             # action = if length(moves_without_q_values) > 0
    #             #     moves_without_q_values[rand(1:end)]
    #             # else 
    #             #     moves_with_q_values[rand(1:end)]
    #             # end

    #             current_q_key = get_q_key(gym.taken_moves, action)
    #             current_q_value = get_q_value(q_table, current_q_key)
                
    #             # this should always be zero and probably can be avoided
    #             max_next_q = max_q_value_for_state(q_table, gym.taken_moves, gym.possible_moves)

    #             reward = estimate_value_of_move(q_table, gym, action)
        
    #             q_table[current_q_key] = (1 - learning_rate) * current_q_value + learning_rate * (reward + discount * max_next_q)

    #             # println("$episode expand($is_epsilon_explore): $reward $(q_table[current_q_key]) action: $(action)")
        
    #             episode_complete = true
    #         else
                
    #             action = select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves)
                
    #             current_q_key = get_q_key(gym.taken_moves, action)
    #             current_q_value = get_q_value(q_table, current_q_key)
                
    #             step(gym, action)
                
    #             max_next_q = max_q_value_for_state(q_table, gym.taken_moves, gym.possible_moves)

    #             reward = -1
        
    #             q_table[current_q_key] = (1 - learning_rate) * current_q_value + learning_rate * (reward + discount * max_next_q)

    #             # println("$episode exploit: $(current_q_value) $max_next_q $(q_table[current_q_key]) $action")
                
    #             if length(gym.possible_moves) == 0
    #                 episode_complete = true
    #             end
    #         end
    #     end

    #     episode_score = length(gym.taken_moves)
    #     max_score = max(max_score, episode_score)

    #     println("$episode: $(episode_score) max: $max_score $(length(q_table))")
    # end

    # # gym = new_gym(board_template)
    # # for possible_move in gym.possible_moves
    # #     state_q_key = get_q_key(Move[], possible_move)
    # #     state_q_value = get_q_value(q_table, state_q_key)
    # #     println("$possible_move $state_q_value")
    # # end

    # gym = new_gym(board_template)
    # while length(gym.possible_moves) > 0
    #     action = select_possible_move_by_policy(q_table, gym.taken_moves, gym.possible_moves)
    #     step(gym, action)
    # end

    # println("greedy: $(length(gym.taken_moves))")

    

    # println(q_table)
    
    
    # selection
    


    # discount = 1
    # alpha = 0.5 # step_size
    # epsilon = 0.1
    
    # q_table = Dict{UInt64,Float64}()

    # num_episodes = 1000


    # for current_episode in 1:num_episodes

    #     gym = new_gym(board_template)



    #     episode_q_keys = UInt64[]
    #     # println(gym.possible_moves)
    #     stop_episode = false
    #     state = Move[]
    #     while(!stop_episode)
    #         # action selection
    #         is_explore = rand() < epsilon 
    #         move_action = if is_explore 
    #             select_random_possible_move(gym) 
    #         else
    #             select_by_policy(q_table, gym, state)
    #         end

    #         # random_move = gym.possible_moves[rand(1:end)]
    #         # println("Making move: $random_move")
    #         next_state, stop_episode = step(gym, move_action)

    #         if (length(gym.possible_moves) > 0)
    #             reward = 1
    #             state_q_key = q_key(state, move_action)
    #             next_q_values = map(possible_move->get_q_value(q_table, q_key(next_state, possible_move)), gym.possible_moves)
    #             max_next_q_value = maximum(next_q_values)
    #             # println(state)
                
    #             # println(map(possible_move->q_key(next_state, possible_move), gym.possible_moves))
    #             # println(next_q_values)
    #             current_q_value = get_q_value(q_table, state_q_key)
    #             t = current_q_value + alpha * ( reward + discount * ( max_next_q_value ) -  current_q_value)
    #             q_table[state_q_key] = t

    #             # println(t)
                
    #         end

    #         state = next_state

    #         # println(state)
    #         # println(lines_hash(state))

    #         # println()

    #         # push!(episode_q_keys, lines_hash(state))


    #     end

    #     println("$current_episode: $(length(gym.taken_moves))")
    # end

    # gym = new_gym(board_template)
    # for possible_move in gym.possible_moves
    #     state_q_key = q_key(Move[], possible_move)
    #     state_q_value = get_q_value(q_table, state_q_key)
    #     println("$possible_move $state_q_value")
    # end


    

    # println(gym.taken_moves)
    # println(length(gym.taken_moves))

    # println()

    # for q_key in reverse(episode_q_keys)
        
    #     current_q_value = haskey(q_table, q_key) ? q_table[q_key] : 0
        

    # end

    # println(length(gym.taken_moves))
    # println(episode_state_action_pairs)
    

    # println(gym.taken_moves, length(gym.possible_moves))

    # moves = random_completion(copy(board_template))

    # score = length(moves)
    # episode_reward = score

    # println("score: $score")
    # println(moves)

    # map(function(index)
    #     # println("$(moves[index]) $(lines_hash(moves[1:index]))")


    #     # state = moves[1:(score - index)]
    #     # action = moves[score - index + 1]
    #     state_action = moves[1:(score - index + 1)]
    #     t = discount_factor^(index - 1)
    #     println("$(length(state_action)) $(t) $(episode_reward * t)")


    #     # println(length(state), action)
    #     # println()
    # end, 1:(score))

    # map((index)->println("$(moves[index]) $(lines_hash(moves[1:index]))"), 1:score)



    
    # println(moves)
    # println(lines_hash(moves))
    # map((move)->println("$(move) -> $(build_move_line_key(move))"), moves)

    


    # subject = build_subject(board_template)


    # subjects = Subject[]

    # for i in 1:10
    #     push!(subjects, build_subject(board_template))
    # end

    # iterations = 400

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
    #         if rand(Bool)# > 0.5
    #             subject = maxby(function(subject)
    #                 subject.max_score
    #             end, subjects)
    #         else
    #             subject = subjects[rand(1:end)]
    #         end

    #         #UCB TODO
    #         # subject = maxby(function(subject)
    #         #     ucb = (step / subject.step) + √(200 * (log(step) / subject.step))

    #         #     # println("$(subject.max_score) $(ucb)")

    #         #     # readline()

    #         #     ucb
    #         # end, subjects)

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