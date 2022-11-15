module univ2::pool {
    use sui::balance::{Self, Balance, Supply};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use univ2::amm_core::{get_lp_coin_by_coinx_coiny_amount, get_coinx_coiny_by_lp_coin, get_amount_out, get_fee};
    use univ2::constants::{get_default_fee, get_min_lp_value};
    use univ2::global::{Self, Global, get_manager_address};

    friend univ2::swap;

    const EZeroAmount: u64 = 0;
    const ENotAllow: u64 = 1;

    const MAX_POOL_VALUE: u64 = {
        18446744073709551615 / 10000
    };

    const EPoolFull: u64 = 4;

    const EReservesEmpty: u64 = 2;


    struct LPCoin<phantom X, phantom Y> has drop {}

    struct Pool<phantom X, phantom Y> has store, key {
        id: UID,
        enable: bool,
        reserve_x: Balance<X>,
        reserve_y: Balance<Y>,

        fee_x: Balance<X>,
        fee_y: Balance<Y>,

        dao_fee: u64,
        lp_fee: u64,
        locked_lp: Balance<LPCoin<X, Y>>,
        lp_supply: Supply<LPCoin<X, Y>>
    }


    public entry fun withdraw_fee<X, Y>(pool: &mut Pool<X, Y>, g: &Global, to: address, amount_x: u64, amount_y: u64, ctx: &mut TxContext) {
        assert!(global::get_withdraw_address(g) == tx_context::sender(ctx), ENotAllow);

        let balance_x = balance::split(&mut pool.fee_x, amount_x);
        let balance_y = balance::split(&mut pool.fee_y, amount_y);
        transfer::transfer(coin::from_balance(balance_x, ctx), to);
        transfer::transfer(coin::from_balance(balance_y, ctx), to);
    }

    public entry fun set_dao_fee<X, Y>(pool: &mut Pool<X, Y>, g: &Global, fee: u64, ctx: &mut TxContext) {
        let sender_address = tx_context::sender(ctx);
        let (manager_address1, manager_address12) = get_manager_address(g) ;
        assert!(manager_address1 == sender_address || manager_address12 == sender_address, ENotAllow);
        pool.dao_fee = fee;
    }

    public entry fun set_lp_fee<X, Y>(pool: &mut Pool<X, Y>, g: &Global, fee: u64, ctx: &mut TxContext) {
        let sender_address = tx_context::sender(ctx);
        let (manager_address1, manager_address12) = get_manager_address(g) ;
        assert!(manager_address1 == sender_address || manager_address12 == sender_address, ENotAllow);
        pool.lp_fee = fee;
    }


    public(friend) fun create_pool<X, Y>(ctx: &mut TxContext):ID {
        let (dao_fee, lp_fee) = get_default_fee();

        let pool = Pool<X, Y> {
            id:object::new(ctx),
            enable: true,
            reserve_x: balance::zero(),
            reserve_y: balance::zero(),
            fee_x: balance::zero(),
            fee_y: balance::zero(),
            locked_lp: balance::zero(),
            dao_fee,
            lp_fee,
            lp_supply: balance::create_supply(LPCoin<X, Y> {})
        };

        let id = object::id(&pool);

        transfer::share_object(pool);
        id
    }

    public(friend) fun add_liquidity<X, Y>(pool: &mut Pool<X, Y>, coin_x: Coin<X>, coin_y: Coin<Y>, ctx: &mut TxContext): Coin<LPCoin<X, Y>> {
        let (coin_x_value, coin_y_value) = (coin::value(&coin_x), coin::value(&coin_y));

        assert!(coin_x_value > 0, EZeroAmount);
        assert!(coin_y_value > 0, EZeroAmount);


        let coin_x_balance = coin::into_balance(coin_x);
        let coin_y_balance = coin::into_balance(coin_y);

        let (reserve_x, reserve_y, lp_supply) = get_reserve(pool);

        let share_minted = get_lp_coin_by_coinx_coiny_amount(coin_x_value, coin_y_value, (lp_supply as u128), reserve_x, reserve_y);

        let sui_amt = balance::join(&mut pool.reserve_x, coin_x_balance);
        let tok_amt = balance::join(&mut pool.reserve_y, coin_y_balance);

        assert!(sui_amt < MAX_POOL_VALUE, EPoolFull);
        assert!(tok_amt < MAX_POOL_VALUE, EPoolFull);
        let balance_lp = balance::increase_supply(&mut pool.lp_supply, share_minted);

        if (lp_supply == 0) {
            balance::join(&mut pool.locked_lp, balance::split(&mut balance_lp, get_min_lp_value()));
        };
        coin::from_balance(balance_lp, ctx)
    }


    public(friend) fun remove_liquidity<X, Y>(pool: &mut Pool<X, Y>, lp: Coin<LPCoin<X, Y>>,
                                              ctx: &mut TxContext): (Coin<X>, Coin<Y>, u64, u64) {
        let lp_amount = coin::value(&lp);
        assert!(lp_amount > 0, EZeroAmount);
        let (reserve_x, reserve_y, lp_supply) = get_reserve(pool);
        let (x_removed, y_removed) = get_coinx_coiny_by_lp_coin(lp_amount, reserve_x, reserve_y, (lp_supply as u128));

        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp));
        (
            coin::take(&mut pool.reserve_x, x_removed, ctx),
            coin::take(&mut pool.reserve_y, y_removed, ctx), x_removed, y_removed
        )
    }


    public(friend) fun swap_x_to_y<CoinIn, CoinOut>(pool: &mut Pool<CoinIn, CoinOut>, in: Coin<CoinIn>, ctx: &mut TxContext): Coin<CoinOut> {
        let in_value = coin::value(&in);
        assert!(in_value > 0, EZeroAmount);


        let dao_fee = get_fee(in_value, pool.dao_fee);
        let lp_fee = get_fee(in_value, pool.lp_fee);
        let dao_coin = coin::split(&mut in, dao_fee, ctx);
        coin::put(&mut pool.fee_x, dao_coin);

        let in_balance = coin::into_balance(in);

        let (reserve_in, reserve_out, _) = get_reserve(pool);

        assert!(reserve_in > 0 && reserve_out > 0, EReservesEmpty);

        let output_amount = get_amount_out(in_value - dao_fee - lp_fee, reserve_in, reserve_out);

        balance::join(&mut pool.reserve_x, in_balance);
        coin::take(&mut pool.reserve_y, output_amount, ctx)
    }


    public(friend) fun swap_y_to_x<CoinIn, CoinOut>(pool: &mut Pool<CoinOut, CoinIn>, in: Coin<CoinIn>, ctx: &mut TxContext): Coin<CoinOut> {
        let in_value = coin::value(&in);
        assert!(in_value > 0, EZeroAmount);


        let dao_fee = get_fee(in_value, pool.dao_fee);
        let lp_fee = get_fee(in_value, pool.lp_fee);
        let dao_coin = coin::split(&mut in, dao_fee, ctx);
        coin::put(&mut pool.fee_y, dao_coin);


        let in_balance = coin::into_balance(in);

        let (reserve_out, reserve_in, _) = get_reserve(pool);

        assert!(reserve_in > 0 && reserve_out > 0, EReservesEmpty);

        let output_amount = get_amount_out(in_value - lp_fee - dao_fee, reserve_in, reserve_out);

        balance::join(&mut pool.reserve_y, in_balance);
        coin::take(&mut pool.reserve_x, output_amount, ctx)
    }


    public fun get_reserve<X, Y>(pool: &Pool<X, Y>): (u64, u64, u64) {
        (
            balance::value(&pool.reserve_x),
            balance::value(&pool.reserve_y),
            balance::supply_value(&pool.lp_supply)
        )
    }
}
