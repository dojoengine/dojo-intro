use crate::models::Direction;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IActions<T> {
    fn spawn(ref self: T);
    fn move(ref self: T, direction: Direction);
    fn move_random(ref self: T, vrf_provider_address: ContractAddress);
}

#[starknet::interface]
trait IVrfProvider<T> {
    fn request_random(self: @T, caller: ContractAddress, source: Source);
    fn consume_random(ref self: T, source: Source) -> felt252;
}

#[derive(Drop, Copy, Clone, Serde)]
pub enum Source {
    Nonce: ContractAddress,
    Salt: felt252,
}

#[dojo::contract]
pub mod actions {
    use super::{IActions, IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};
    use crate::models::{Direction, Moves, Position, PositionTrait};

    use starknet::ContractAddress;
    use core::num::traits::SaturatingSub;
    use dojo::model::ModelStorage;

    pub const INIT_COORD: u32 = 10;
    pub const INIT_REMAINING_MOVES: u8 = 100;

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(ref self: ContractState) {
            let mut world = self.world_default();

            let player = starknet::get_caller_address();

            let position = Position {
                player,
                x: INIT_COORD,
                y: INIT_COORD,
            };

            let moves = Moves {
                player,
                remaining: INIT_REMAINING_MOVES,
            };

            world.write_model(@position);
            world.write_model(@moves);
        }

        fn move(ref self: ContractState, direction: Direction) {
            let mut world = self.world_default();

            let player = starknet::get_caller_address();

            let mut position: Position = world.read_model(player);
            position.apply_direction(direction);
            world.write_model(@position);

            let mut moves: Moves = world.read_model(player);
            moves.remaining = moves.remaining.saturating_sub(1);
            world.write_model(@moves);
        }

        fn move_random(ref self: ContractState, vrf_provider_address: ContractAddress) {
            let player = starknet::get_caller_address();

            let vrf_provider = IVrfProviderDispatcher { contract_address: vrf_provider_address };
            let random_value: u256 = vrf_provider.consume_random(Source::Nonce(player)).into();
            let random_dir: felt252 = (random_value % 4).try_into().unwrap();

            let direction = match random_dir {
                0 => Direction::Up,
                1 => Direction::Down,
                2 => Direction::Left,
                3 => Direction::Right,
                _ => panic!("Invalid random direction"),
            };

            self.move(direction);
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"di")
        }
    }
}
