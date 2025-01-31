/// constant for
module enchanter_swap::constants {
    /// fee base of percentage
    public fun get_fee_base_of_percentage(): u64 { 100000 }

    /// 0.05% default dao fee
    public fun get_default_fee(): (u64, u64) { (50, 250) }

    ///  1% max fee for lp and dao
    public fun get_max_fee(): u64 { 1000 }

    ///  min lp value will lock in dao bank
    public fun get_min_lp_value(): u64 { 1000 }
}
