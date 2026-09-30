// =========================================================================
// CHECKERS vs AI
// You play RED (moves upward), the computer plays BLACK (moves downward).
// Diagonal moves, multi-jumps, kings. Captures are OPTIONAL (not forced) -
// you can always choose a plain step instead of an available jump.
// AI: minimax search with alpha-beta pruning. AI pauses briefly before moving.
// Difficulty buttons (Easy/Medium/Hard/Insane) control search depth; Easy
// also has a chance to play a deliberately weaker move.
// =========================================================================

final int EMPTY = 0, RED = 1, RED_KING = 2, BLACK = 3, BLACK_KING = 4;
final int SIZE = 8;
final int CELL = 70;
final int OFFX = 30, OFFY = 110;
final int AI_DELAY_MS = 800; // pause before the AI actually makes its move

// Difficulty = search depth, plus a chance of a deliberately weaker move on Easy.
final int[] DEPTHS       = {2, 6, 8, 10};
final float[] RANDOMNESS = {0.45f, 0f, 0f, 0f}; // chance Easy ignores the best move
final String[] DIFF_NAMES = {"Easy", "Medium", "Hard", "Insane"};
int difficulty = 1; // 0=Easy, 1=Medium (default), 2=Hard, 3=Insane

int[][] board = new int[SIZE][SIZE];
boolean redTurn = true;      // human (red) moves first
boolean gameOver = false;
String statusMsg = "";
boolean aiPending = false;
int aiPendingStart = -1;

int selR = -1, selC = -1;
ArrayList<Move> selectedMoves = new ArrayList<Move>();

class Move {
  ArrayList<int[]> path = new ArrayList<int[]>();
  ArrayList<int[]> captured = new ArrayList<int[]>();
}

// =========================================================================
void setup() {
  size(620, 780);
  surface.setTitle("Checkers vs AI");
  initBoard();
}

void initBoard() {
  for (int r = 0; r < SIZE; r++)
    for (int c = 0; c < SIZE; c++)
      board[r][c] = EMPTY;

  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      if ((r + c) % 2 == 1) {
        if (r < 3) board[r][c] = BLACK;
        else if (r > 4) board[r][c] = RED;
      }
    }
  }
  redTurn = true;
  gameOver = false;
  aiPending = false;
  selR = -1; selC = -1;
  selectedMoves.clear();
  statusMsg = "Your move (red)";
}

// =========================================================================
void draw() {
  background(40);
  drawBoard();
  drawPieces();
  drawHighlights();
  drawUI();

  if (aiPending && millis() - aiPendingStart >= AI_DELAY_MS) {
    aiPending = false;
    performAIMove();
  }
}

void drawBoard() {
  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      fill((r + c) % 2 == 0 ? color(235, 220, 195) : color(90, 60, 40));
      noStroke();
      rect(OFFX + c * CELL, OFFY + r * CELL, CELL, CELL);
    }
  }
}

void drawPieces() {
  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = board[r][c];
      if (p == EMPTY) continue;
      float cx = OFFX + c * CELL + CELL / 2.0f;
      float cy = OFFY + r * CELL + CELL / 2.0f;
      float d = CELL * 0.72f;

      noStroke();
      fill(0, 90);
      ellipse(cx + 3, cy + 4, d, d);

      fill(isRed(p) ? color(200, 40, 40) : color(30, 30, 30));
      stroke(255, 230);
      strokeWeight(2);
      ellipse(cx, cy, d, d);

      if (isKing(p)) {
        fill(255, 210, 60);
        textAlign(CENTER, CENTER);
        textSize(20);
        noStroke();
        text("K", cx, cy);
      }
    }
  }
}

void drawHighlights() {
  if (selR != -1) {
    noFill();
    stroke(80, 220, 255);
    strokeWeight(3);
    rect(OFFX + selC * CELL, OFFY + selR * CELL, CELL, CELL);

    noStroke();
    fill(80, 220, 255, 150);
    for (Move m : selectedMoves) {
      int[] to = m.path.get(m.path.size() - 1);
      ellipse(OFFX + to[1] * CELL + CELL / 2.0f, OFFY + to[0] * CELL + CELL / 2.0f, 18, 18);
    }
  }
}

void drawUI() {
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text(statusMsg, width / 2, 22);

  drawDifficultyButtons();

  fill(80, 200, 130);
  stroke(255);
  strokeWeight(1);
  rect(width / 2 - 70, height - 46, 140, 34, 8);
  fill(20);
  noStroke();
  textSize(15);
  text("New Game", width / 2, height - 29);
}

float diffBtnX(int i) { return 35 + i * 140; }

void drawDifficultyButtons() {
  for (int i = 0; i < 4; i++) {
    boolean active = (i == difficulty);
    boolean hov = hit(diffBtnX(i), 48, 130, 28);
    fill(active ? color(80, 200, 130) : (hov ? color(90) : color(65)));
    stroke(255, 160);
    strokeWeight(1);
    rect(diffBtnX(i), 48, 130, 28, 6);
    fill(active ? 20 : 230);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(14);
    text(DIFF_NAMES[i], diffBtnX(i) + 65, 63);
  }
}

// =========================================================================
// PIECE HELPERS
// =========================================================================
boolean isRed(int p)   { return p == RED || p == RED_KING; }
boolean isBlack(int p) { return p == BLACK || p == BLACK_KING; }
boolean isKing(int p)  { return p == RED_KING || p == BLACK_KING; }
boolean inBounds(int r, int c) { return r >= 0 && r < SIZE && c >= 0 && c < SIZE; }

int[][] jumpDirs(int piece) {
  if (piece == RED_KING || piece == BLACK_KING)
    return new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}};
  if (piece == RED)
    return new int[][]{{-1,-1},{-1,1}};
  return new int[][]{{1,-1},{1,1}}; // BLACK man
}

int[][] copyBoard(int[][] b) {
  int[][] nb = new int[SIZE][SIZE];
  for (int r = 0; r < SIZE; r++) nb[r] = b[r].clone();
  return nb;
}

// =========================================================================
// MOVE GENERATION
// =========================================================================
// Captures are optional now: this returns every legal move (jumps AND plain
// steps) for the side, rather than forcing a jump whenever one is available.
ArrayList<Move> getAllMoves(int[][] b, boolean redSide) {
  ArrayList<Move> moves = new ArrayList<Move>();

  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = b[r][c];
      if (p == EMPTY) continue;
      if (redSide && !isRed(p)) continue;
      if (!redSide && !isBlack(p)) continue;
      ArrayList<int[]> path = new ArrayList<int[]>();
      path.add(new int[]{r, c});
      findCaptures(b, r, c, path, new ArrayList<int[]>(), moves, redSide);
    }
  }

  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = b[r][c];
      if (p == EMPTY) continue;
      if (redSide && !isRed(p)) continue;
      if (!redSide && !isBlack(p)) continue;
      for (int[] d : jumpDirs(p)) {
        int lr = r + d[0], lc = c + d[1];
        if (inBounds(lr, lc) && b[lr][lc] == EMPTY) {
          Move m = new Move();
          m.path.add(new int[]{r, c});
          m.path.add(new int[]{lr, lc});
          moves.add(m);
        }
      }
    }
  }
  return moves;
}

// recursively extends a jump sequence; records a Move each time a branch runs out of further jumps
void findCaptures(int[][] b, int r, int c, ArrayList<int[]> path, ArrayList<int[]> captured, ArrayList<Move> results, boolean redSide) {
  int piece = b[r][c];
  boolean found = false;

  for (int[] d : jumpDirs(piece)) {
    int mr = r + d[0], mc = c + d[1];
    int lr = r + d[0] * 2, lc = c + d[1] * 2;
    if (!inBounds(lr, lc) || !inBounds(mr, mc)) continue;
    if (b[lr][lc] != EMPTY) continue;
    int mid = b[mr][mc];
    if (mid == EMPTY) continue;
    if (redSide && isRed(mid)) continue;
    if (!redSide && isBlack(mid)) continue;

    int[][] nb = copyBoard(b);
    nb[r][c] = EMPTY;
    nb[mr][mc] = EMPTY;
    int newPiece = piece;
    if (piece == RED && lr == 0) newPiece = RED_KING;
    if (piece == BLACK && lr == SIZE - 1) newPiece = BLACK_KING;
    nb[lr][lc] = newPiece;

    ArrayList<int[]> newPath = new ArrayList<int[]>(path);
    newPath.add(new int[]{lr, lc});
    ArrayList<int[]> newCaptured = new ArrayList<int[]>(captured);
    newCaptured.add(new int[]{mr, mc});

    found = true;
    findCaptures(nb, lr, lc, newPath, newCaptured, results, redSide);
  }

  if (!found && captured.size() > 0) {
    Move m = new Move();
    m.path = path;
    m.captured = captured;
    results.add(m);
  }
}

int[][] applyMove(int[][] b, Move m) {
  int[][] nb = copyBoard(b);
  int[] from = m.path.get(0);
  int[] to = m.path.get(m.path.size() - 1);
  int piece = nb[from[0]][from[1]];
  nb[from[0]][from[1]] = EMPTY;
  for (int[] cap : m.captured) nb[cap[0]][cap[1]] = EMPTY;
  if (piece == RED && to[0] == 0) piece = RED_KING;
  if (piece == BLACK && to[0] == SIZE - 1) piece = BLACK_KING;
  nb[to[0]][to[1]] = piece;
  return nb;
}

// =========================================================================
// AI: minimax with alpha-beta pruning (maximizes for BLACK)
// =========================================================================
float evaluate(int[][] b) {
  float score = 0;
  for (int r = 0; r < SIZE; r++) {
    for (int c = 0; c < SIZE; c++) {
      int p = b[r][c];
      if (p == RED)        score -= 1.0f + 0.02f * (SIZE - 1 - r);
      else if (p == RED_KING)   score -= 1.6f;
      else if (p == BLACK)      score += 1.0f + 0.02f * r;
      else if (p == BLACK_KING) score += 1.6f;
    }
  }
  return score;
}

float minimax(int[][] b, int depth, float alpha, float beta, boolean blackToMove) {
  ArrayList<Move> moves = getAllMoves(b, !blackToMove);
  if (moves.isEmpty()) return blackToMove ? -1000 : 1000; // side to move has no moves = they lose
  if (depth == 0) return evaluate(b);

  if (blackToMove) {
    float best = -Float.MAX_VALUE;
    for (Move m : moves) {
      float score = minimax(applyMove(b, m), depth - 1, alpha, beta, false);
      best = max(best, score);
      alpha = max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  } else {
    float best = Float.MAX_VALUE;
    for (Move m : moves) {
      float score = minimax(applyMove(b, m), depth - 1, alpha, beta, true);
      best = min(best, score);
      beta = min(beta, best);
      if (beta <= alpha) break;
    }
    return best;
  }
}

void performAIMove() {
  ArrayList<Move> moves = getAllMoves(board, false);
  if (moves.isEmpty()) {
    gameOver = true;
    statusMsg = "You win! AI has no moves left.";
    return;
  }

  int depth = DEPTHS[difficulty];
  float bestScore = -Float.MAX_VALUE;
  Move bestMove = moves.get(0);
  for (Move m : moves) {
    float score = minimax(applyMove(board, m), depth - 1, -Float.MAX_VALUE, Float.MAX_VALUE, false);
    if (score > bestScore) {
      bestScore = score;
      bestMove = m;
    }
  }

  // Easy occasionally throws away the best move in favor of a random legal one
  if (random(1) < RANDOMNESS[difficulty]) {
    bestMove = moves.get(int(random(moves.size())));
  }

  board = applyMove(board, bestMove);
  redTurn = true;

  ArrayList<Move> redMoves = getAllMoves(board, true);
  if (redMoves.isEmpty()) {
    gameOver = true;
    statusMsg = "AI wins! You have no moves left.";
  } else {
    statusMsg = "Your move (red)";
  }
}

// =========================================================================
// INTERACTION
// =========================================================================
void mousePressed() {
  for (int i = 0; i < 4; i++) {
    if (hit(diffBtnX(i), 48, 130, 28)) {
      difficulty = i;
      return;
    }
  }

  if (hit(width / 2 - 70, height - 46, 140, 34)) {
    initBoard();
    return;
  }
  if (gameOver || !redTurn || aiPending) return;

  int col = (mouseX - OFFX) / CELL;
  int row = (mouseY - OFFY) / CELL;
  if (!inBounds(row, col)) return;

  if (selR == -1) {
    ArrayList<Move> allRed = getAllMoves(board, true);
    ArrayList<Move> forThis = new ArrayList<Move>();
    for (Move m : allRed) {
      int[] from = m.path.get(0);
      if (from[0] == row && from[1] == col) forThis.add(m);
    }
    if (!forThis.isEmpty()) {
      selR = row; selC = col;
      selectedMoves = forThis;
    }
  } else {
    if (row == selR && col == selC) {
      selR = -1; selectedMoves.clear();
      return;
    }
    Move chosen = null;
    for (Move m : selectedMoves) {
      int[] to = m.path.get(m.path.size() - 1);
      if (to[0] == row && to[1] == col) { chosen = m; break; }
    }
    if (chosen != null) {
      board = applyMove(board, chosen);
      selR = -1; selectedMoves.clear();

      ArrayList<Move> blackMoves = getAllMoves(board, false);
      if (blackMoves.isEmpty()) {
        gameOver = true;
        statusMsg = "You win! AI has no moves left.";
      } else {
        redTurn = false;
        aiPending = true;
        aiPendingStart = millis();
        statusMsg = "AI is thinking...";
      }
    } else if (isRed(board[row][col])) {
      // clicked a different one of your pieces - try reselecting
      ArrayList<Move> allRed = getAllMoves(board, true);
      ArrayList<Move> forThis = new ArrayList<Move>();
      for (Move m : allRed) {
        int[] from = m.path.get(0);
        if (from[0] == row && from[1] == col) forThis.add(m);
      }
      if (!forThis.isEmpty()) {
        selR = row; selC = col;
        selectedMoves = forThis;
      }
    }
  }
}

boolean hit(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}
