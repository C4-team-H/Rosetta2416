enum GamePhase: Equatable {
    case preparing
    case playing
    case drawing(String)
    case cutscene(StoryCutscene)
    case victory
    case gameOver
    case disconnected
}
