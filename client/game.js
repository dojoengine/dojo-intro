/**
 * Game logic.
 *
 * Updates the UI by parsing Torii responses.
 * Sends transactions to the chain using controller account.
 */

const NAMESPACE = 'di';
const POSITION_MODEL = 'Position';
const MOVES_MODEL = 'Moves';

const ACTIONS_CONTRACT = 'di-actions';

function updateFromEntitiesData(entities) {
  entities.forEach((entity) => {
    updateFromEntityData(entity);
  });
}

function updateFromEntityData(entity) {
  if (entity.models) {
    if (entity.models[NAMESPACE][POSITION_MODEL]) {
      const position = entity.models[NAMESPACE][POSITION_MODEL];
      updatePositionDisplay(position.x, position.y);
    }

    if (entity.models[NAMESPACE][MOVES_MODEL]) {
      const moves = entity.models[NAMESPACE][MOVES_MODEL];
      updateMovesDisplay(moves.remaining);
    }
  }
}

function updatePositionDisplay(x, y) {
  const positionDisplay = document.getElementById('position-display');
  if (positionDisplay) {
    positionDisplay.textContent = `Position: (${x}, ${y})`;
  }
}

function updateMovesDisplay(remaining) {
  const movesDisplay = document.getElementById('moves-display');
  if (movesDisplay) {
    movesDisplay.textContent = `Moves remaining: ${remaining}`;
  }
}

function initGame(account, manifest) {
  document.getElementById('up-button').onclick = async () => {
    await move(account, manifest, 'up');
  };
  document.getElementById('right-button').onclick = async () => {
    await move(account, manifest, 'right');
  };
  document.getElementById('down-button').onclick = async () => {
    await move(account, manifest, 'down');
  };
  document.getElementById('left-button').onclick = async () => {
    await move(account, manifest, 'left');
  };
  document.getElementById('move-random-button').onclick = async () => {
    await moveRandom(account, manifest);
  };

  document.getElementById('spawn-button').onclick = async () => {
    await spawn(account, manifest);

    document.getElementById('up-button').disabled = false;
    document.getElementById('right-button').disabled = false;
    document.getElementById('down-button').disabled = false;
    document.getElementById('left-button').disabled = false;
    document.getElementById('move-random-button').disabled = false;
  };
}

async function spawn(account, manifest) {
  const tx = await account.execute({
    contractAddress: manifest.contracts.find((contract) => contract.tag === ACTIONS_CONTRACT)
      .address,
    entrypoint: 'spawn',
    calldata: [],
  });

  console.log('Transaction sent:', tx);
}

async function move(account, manifest, direction) {
  let calldata;

  // Cairo serialization uses the variant index to determine the direction.
  // Refer to models.cairo in contracts folder.
  switch (direction) {
    case 'left':
      calldata = ['0'];
      break;
    case 'right':
      calldata = ['1'];
      break;
    case 'up':
      calldata = ['2'];
      break;
    case 'down':
      calldata = ['3'];
      break;
  }

  const tx = await account.execute({
    contractAddress: manifest.contracts.find((contract) => contract.tag === ACTIONS_CONTRACT)
      .address,
    entrypoint: 'move',
    calldata: calldata,
  });

  console.log('Transaction sent:', tx);
}

//const VRF_PROVIDER_ADDRESS = '0x15f542e25a4ce31481f986888c179b6e57412be340b8095f72f75a328fbb27b';
const VRF_PROVIDER_ADDRESS = '0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f';

// VRF -> we need to sandwitch the `consume_random` as defined here:
// https://docs.cartridge.gg/vrf/overview#executing-vrf-transactions
async function moveRandom(account, manifest) {
  let action_addr = manifest.contracts.find(
    (contract) => contract.tag === ACTIONS_CONTRACT,
  ).address;

  const tx = await account.execute([
    {
      contractAddress: VRF_PROVIDER_ADDRESS,
      entrypoint: 'request_random',
      calldata: [action_addr, '0', account.address],
    },
    {
      contractAddress: action_addr,
      entrypoint: 'move_random',
      calldata: [VRF_PROVIDER_ADDRESS],
    },
  ]);

  console.log('Transaction sent:', tx);
}

export { initGame, updateFromEntitiesData };
