module univ2::events {
    use std::string::{Self, String};

    use sui::event;

    struct AddLpEvent has drop, copy {
        /// signer of sender address
        sender: address,
        /// LpCoin value by user X and Y type
        lp: u64,
        /// code of X name
        coin_x: String,
        /// code of Y name
        coin_y: String,
        /// user input x
        input_x: u64,
        /// user input y
        input_y: u64,
        ///  real cost x
        real_x: u64,
        ///  real cost y
        real_y: u64,
        /// reserve x
        reserve_x: u64,
        /// reserve y
        reserve_y: u64,
        /// total lp
        total_lp: u128
    }

    /// event emitted when remove token LpCoin.
    struct RemoveLpEvent has drop, copy {
        /// signer of sender address
        sender: address,
        /// code of X name
        coin_x: String,
        /// code of Y name
        coin_y: String,
        /// Lp coin value by user X and Y
        lp: u64,
        /// remove fee
        fee: u64,
        /// user input min x amount
        min_x: u64,
        /// user input min y amount
        min_y: u64,
        /// real get x amount
        real_x: u64,
        /// real get y amount
        real_y: u64,
        /// reserve x
        reserve_x: u64,
        /// reserve y
        reserve_y: u64,
        /// total lp
        total_lp: u128
    }

    /// event emitted when token swap.
    struct SwapEvent has drop, copy {
        /// who
        sender: address,
        /// in coin name
        in_coin: String,
        /// out coin name
        out_coin: String,
        /// in coin amount
        in_amount: u64,
        /// The amount of   get
        out_amount: u64,
        // user input mini out amount(exact_in) or user max in amount(exact_out)
        user_limit_amount: u64,
        /// fee for dao service
        dao_fee: u64,
        /// fee for lp provider
        lp_fee: u64,
        /// reserve x
        reserve_x: u64,
        /// reserve y
        reserve_y: u64
    }


    /// Emit add lp pool event
    public(friend) fun emit_add_lp_event(
        sender: address,
        lp: u64,
        input_x: u64,
        input_y: u64,
        real_x: u64,
        real_y: u64,
        reserve_x: u64,
        reserve_y: u64,
        total_lp: u128
    ) {
        event::emit(AddLpEvent {
            sender,
            coin_x: string::utf8(b""),
            coin_y: string::utf8(b""),
            lp,
            input_x,
            input_y,
            real_x,
            real_y,
            reserve_x,
            reserve_y,
            total_lp
        });
    }

    /// Emit remove lp event
    public(friend) fun emit_remove_lp_coin_event<X, Y>(
        sender: address,
        lp: u64,
        min_x: u64,
        min_y: u64,
        real_x: u64,
        real_y: u64,
        fee: u64,
        reserve_x: u64,
        reserve_y: u64,
        total_lp: u128
    ) {
        event::emit(RemoveLpEvent {
            coin_x: string::utf8(b""),
            coin_y: string::utf8(b""),
            sender,
            lp,
            min_x,
            min_y,
            real_x,
            real_y,
            fee,
            reserve_x,
            reserve_y,
            total_lp
        });
    }

    /// Emit swap event
    public(friend) fun emit_swap_event<X, Y>(
        sender_address: address,
        in_coin: String,
        out_coin: String,
        in_amount: u64,
        // real out amount
        out_amount: u64,
        // user input mini out amount(exact_in) or user max in amount(exact_out)
        user_limit_amount: u64,
        dao_fee: u64,
        lp_fee: u64,
        reserve_x: u64,
        reserve_y: u64
    ) {
        event::emit(SwapEvent {
            sender: sender_address,
            in_coin,
            out_coin,
            in_amount,
            out_amount,
            user_limit_amount,
            dao_fee,
            lp_fee,
            reserve_x,
            reserve_y
        });
    }
}
