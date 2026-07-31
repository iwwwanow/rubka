export class MoveWindowUseCase {
  constructor(private windowManager: WindowManagerPort) {
    this.windowManager = windowManager;
  }

  execute(direction: DirectionEnum) {
    this.windowManager.move(direction);
  }
}
