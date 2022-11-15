module univ2::swap {
    use sui::coin::{Self, Coin};
    use sui::pay;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use univ2::global::{Self, Global, exist_pool};
    use univ2::pool::{Self, Pool, LPCoin};

    const EHaveSlippage: u64 = 0x0001;
    const EPoolExist: u64 = 0x0002;

    public entry fun create_pool<X, Y>(global: &mut Global, ctx: &mut TxContext) {
        assert!(!exist_pool<X, Y>(global) || !exist_pool<Y, X>(global), EPoolExist);
        let id = pool::create_pool<X, Y>(ctx);
        global::add_pool_flag<X, Y>(global,id);
    }

    public entry fun add_liquidity<X, Y>(
        pool: &mut Pool<X, Y>,
        coin_x: vector<Coin<X>>,
        coin_y: vector<Coin<Y>>,
        coin_x_amount: u64,
        coin_x_min: u64,
        coin_y_amount: u64,
        coin_y_min: u64,
        ctx: &mut TxContext) {
        let coin_x_in = coin::zero<X>(ctx);
        pay::join_vec(&mut coin_x_in, coin_x);

        let coin_y_in = coin::zero<Y>(ctx);
        pay::join_vec(&mut coin_y_in, coin_y);

        transfer::transfer(
            pool::add_liquidity(pool, coin_x_in, coin_y_in, ctx),
            tx_context::sender(ctx)
        );
    }

    public entry fun remove_liquidity<X, Y>(
        pool: &mut Pool<X, Y>,
        lp: vector<Coin<LPCoin<X, Y>>>,
        lp_amount: u64,
        min_x: u64,
        min_y: u64,
        ctx: &mut TxContext)
    {
        let lp_in = coin::zero<LPCoin<X, Y>>(ctx);
        pay::join_vec(&mut lp_in, lp);

        let (coin_c, coin_y, x_removed, y_removed) = pool::remove_liquidity(pool, lp_in, ctx);

        assert!(x_removed >= min_x && y_removed >= min_y, EHaveSlippage);

        let sender = tx_context::sender(ctx);

        transfer::transfer(coin_c, sender);
        transfer::transfer(coin_y, sender);
    }


    /// error
    public entry fun swap_x_to_y<CoinIn, CoinOut>(pool: &mut Pool<CoinIn, CoinOut>, in: vector<Coin<CoinIn>>, in_amount: u64, min_out: u64, ctx: &mut TxContext) {
        let in_coin = coin::zero<CoinIn>(ctx);
        pay::join_vec(&mut in_coin, in);
        let out = pool::swap_x_to_y(pool, in_coin, ctx);
        let sender = tx_context::sender(ctx);
        transfer::transfer(out, sender);
    }


    public entry fun swap_y_to_x<CoinOut, CoinIn>(pool: &mut Pool<CoinIn,CoinOut >, in: vector<Coin<CoinIn>>,in_amount: u64, min_out: u64, ctx: &mut TxContext) {
        let in_coin = coin::zero<CoinIn>(ctx);
        pay::join_vec(&mut in_coin, in);
        let out = pool::swap_y_to_x(pool, in_coin, ctx);
        let sender = tx_context::sender(ctx);
        transfer::transfer(out, sender);
    }
}
