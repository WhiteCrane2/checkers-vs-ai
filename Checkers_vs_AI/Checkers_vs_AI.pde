// =========================================================================
// CHECKERS vs AI
// You play RED (moves upward), the computer plays BLACK (moves downward).
// Diagonal moves, multi-jumps, kings. Captures are OPTIONAL (not forced) -
// you can always choose a plain step instead of an available jump.
// AI: minimax search with alpha-beta pruning. AI pauses 2 seconds before
// moving, the same on every difficulty. Difficulty buttons (Easy/Medium/
// Hard/Insane) control search depth; Easy also has a chance to play a
// deliberately weaker move. On top of that, every difficulty has a 1-in-25
// chance per move of deliberately playing into its worst available spot,
// so even Hard/Insane occasionally blunder. Pieces slide smoothly to their destination,
// hop by hop on multi-jumps, instead of jumping there instantly.
// =========================================================================

final int EMPTY = 0, RED = 1, RED_KING = 2, BLACK = 3, BLACK_KING = 4;
final int SIZE = 8;
final int CELL = 70;
final int OFFX = 30, OFFY = 110;
final int AI_DELAY_MS = 2000; // flat artificial "thinking" pause, same on every difficulty

final int[] DEPTHS       = {2, 6, 8, 10};
final float[] RANDOMNESS = {0.45f, 0f, 0f, 0f};
final float BLUNDER_CHANCE = 1.0f / 25.0f;
final String[] DIFF_NAMES = {"Easy", "Medium", "Hard", "Insane"};
int difficulty = 1;

final int ANIM_STEP_MS = 220;
boolean animating = false;
Move animMove = null;
boolean animIsRedMove = false;
int animIndex = 0;
int animStepStart = 0;
int animPieceType = 0;

int[][] board = new int[SIZE][SIZE];
boolean redTurn = true;
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

void draw() {
  if (chessMode) updateCAnimation(); else updateAnimation();

  background(40);
  drawBoard();
  if (chessMode) {
    drawCPieces();
    drawCAnimPiece();
    drawCHighlights();
  } else {
    drawPieces();
    drawAnimPiece();
    drawHighlights();
  }
  drawUI();

  if (chessMode) {
    if (!cAnimating && cAiPending && millis() - cAiPendingStart >= AI_DELAY_MS) {
      cAiPending = false;
      performCAIMove();
    }
  } else {
    if (!animating && aiPending && millis() - aiPendingStart >= AI_DELAY_MS) {
      aiPending = false;
      performAIMove();
    }
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
      if (isHiddenDuringAnim(r, c)) continue;
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
  text(chessMode ? cStatusMsg : statusMsg, width / 2, 22);

  drawDifficultyButtons();

  fill(80, 200, 130);
  stroke(255);
  strokeWeight(1);
  rect(width / 2 - 70, height - 46, 140, 34, 8);
  fill(20);
  noStroke();
  textSize(15);
  text("New Game", width / 2, height - 29);

  fill(90, 140, 220);
  stroke(255);
  strokeWeight(1);
  rect(width - 170, height - 46, 150, 34, 8);
  fill(20);
  noStroke();
  textSize(14);
  text(chessMode ? "Switch to Checkers" : "Switch to Chess", width - 95, height - 29);
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

void startAnimation(Move m, boolean wasRedMove) {
  animMove = m;
  animIsRedMove = wasRedMove;
  animIndex = 0;
  animStepStart = millis();
  int[] src = m.path.get(0);
  animPieceType = board[src[0]][src[1]];
  animating = true;
}

void updateAnimation() {
  if (!animating) return;
  float t = (millis() - animStepStart) / (float) ANIM_STEP_MS;
  if (t >= 1) {
    animIndex++;
    if (animIndex >= animMove.path.size() - 1) {
      finishAnimatedMove();
    } else {
      animStepStart = millis();
    }
  }
}

void drawAnimPiece() {
  if (!animating) return;
  int[] from = animMove.path.get(animIndex);
  int[] to = animMove.path.get(animIndex + 1);
  float t = constrain((millis() - animStepStart) / (float) ANIM_STEP_MS, 0, 1);
  float te = t * t * (3 - 2 * t);

  float cx = lerp(OFFX + from[1] * CELL + CELL / 2.0f, OFFX + to[1] * CELL + CELL / 2.0f, te);
  float cy = lerp(OFFY + from[0] * CELL + CELL / 2.0f, OFFY + to[0] * CELL + CELL / 2.0f, te);
  float d = CELL * 0.72f;

  noStroke();
  fill(0, 90);
  ellipse(cx + 3, cy + 4, d, d);

  fill(isRed(animPieceType) ? color(200, 40, 40) : color(30, 30, 30));
  stroke(255, 230);
  strokeWeight(2);
  ellipse(cx, cy, d, d);

  if (isKing(animPieceType)) {
    fill(255, 210, 60);
    textAlign(CENTER, CENTER);
    textSize(20);
    noStroke();
    text("K", cx, cy);
  }
}

boolean isHiddenDuringAnim(int r, int c) {
  if (!animating) return false;
  int[] src = animMove.path.get(0);
  if (r == src[0] && c == src[1]) return true;
  for (int i = 0; i <= animIndex && i < animMove.captured.size(); i++) {
    int[] cap = animMove.captured.get(i);
    if (r == cap[0] && c == cap[1]) return true;
  }
  return false;
}

void finishAnimatedMove() {
  board = applyMove(board, animMove);
  boolean wasRed = animIsRedMove;
  animating = false;
  animMove = null;

  if (wasRed) {
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
  } else {
    redTurn = true;
    ArrayList<Move> redMoves = getAllMoves(board, true);
    if (redMoves.isEmpty()) {
      gameOver = true;
      statusMsg = "AI wins! You have no moves left.";
    } else {
      statusMsg = "Your move (red)";
    }
  }
}

boolean isRed(int p)   { return p == RED || p == RED_KING; }
boolean isBlack(int p) { return p == BLACK || p == BLACK_KING; }
boolean isKing(int p)  { return p == RED_KING || p == BLACK_KING; }
boolean inBounds(int r, int c) { return r >= 0 && r < SIZE && c >= 0 && c < SIZE; }

int[][] jumpDirs(int piece) {
  if (piece == RED_KING || piece == BLACK_KING)
    return new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}};
  if (piece == RED)
    return new int[][]{{-1,-1},{-1,1}};
  return new int[][]{{1,-1},{1,1}};
}

int[][] copyBoard(int[][] b) {
  int[][] nb = new int[SIZE][SIZE];
  for (int r = 0; r < SIZE; r++) nb[r] = b[r].clone();
  return nb;
}

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
  if (moves.isEmpty()) return blackToMove ? -1000 : 1000;
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
  float worstScore = Float.MAX_VALUE;
  Move bestMove = moves.get(0);
  Move worstMove = moves.get(0);
  for (Move m : moves) {
    float score = minimax(applyMove(board, m), depth - 1, -Float.MAX_VALUE, Float.MAX_VALUE, false);
    if (score > bestScore) {
      bestScore = score;
      bestMove = m;
    }
    if (score < worstScore) {
      worstScore = score;
      worstMove = m;
    }
  }

  Move chosenMove = bestMove;

  if (random(1) < RANDOMNESS[difficulty]) {
    chosenMove = moves.get(int(random(moves.size())));
  }
  else if (random(1) < BLUNDER_CHANCE) {
    chosenMove = worstMove;
  }

  startAnimation(chosenMove, false);
}

void mousePressed() {
  for (int i = 0; i < 4; i++) {
    if (hit(diffBtnX(i), 48, 130, 28)) {
      difficulty = i;
      return;
    }
  }

  if (hit(width - 170, height - 46, 150, 34)) {
    toggleMode();
    return;
  }

  if (chessMode) {
    if (cAnimating) return;
    if (hit(width / 2 - 70, height - 46, 140, 34)) {
      initChessBoard();
      return;
    }
    if (cGameOver || !whiteTurn || cAiPending) return;

    int ccol = (mouseX - OFFX) / CELL;
    int crow = (mouseY - OFFY) / CELL;
    if (!inBounds(crow, ccol)) return;
    handleChessClick(crow, ccol);
    return;
  }

  if (animating) return;

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
      selR = -1; selectedMoves.clear();
      startAnimation(chosen, true);
    } else if (isRed(board[row][col])) {
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

// =========================================================================
// CHESS MODE
// =========================================================================
final int PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6;
final int[] CHESS_DEPTHS = {1, 2, 3, 4};

boolean chessMode = false;

int[][] cboard = new int[SIZE][SIZE];
boolean whiteTurn = true;
boolean cGameOver = false;
String cStatusMsg = "";
boolean cAiPending = false;
int cAiPendingStart = -1;

boolean wKingMoved = false, bKingMoved = false;
boolean wRookAMoved = false, wRookHMoved = false, bRookAMoved = false, bRookHMoved = false;
int epTargetR = -1, epTargetC = -1, epPawnR = -1, epPawnC = -1;

int cSelR = -1, cSelC = -1;
ArrayList<CMove> cSelMoves = new ArrayList<CMove>();

boolean cAnimating = false;
CMove cAnimMove = null;
boolean cAnimWasWhite = false;
int cAnimStepStart = 0;
int cAnimPieceType = 0;
final int CANIM_MS = 260;

class CMove {
  int fr, fc, tr, tc;
  boolean castleK = false, castleQ = false, enPassant = false;
  int epCapR = -1, epCapC = -1;
}

void initChessBoard() {
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) cboard[r][c] = 0;
  int[] order = {ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK};
  for (int c = 0; c < 8; c++) {
    cboard[0][c] = -order[c];
    cboard[1][c] = -PAWN;
    cboard[6][c] = PAWN;
    cboard[7][c] = order[c];
  }
  whiteTurn = true;
  cGameOver = false;
  cAiPending = false;
  cAnimating = false;
  cSelR = -1; cSelC = -1; cSelMoves.clear();
  wKingMoved = false; bKingMoved = false;
  wRookAMoved = false; wRookHMoved = false; bRookAMoved = false; bRookHMoved = false;
  epTargetR = -1; epTargetC = -1; epPawnR = -1; epPawnC = -1;
  cStatusMsg = "Your move (white)";
}

void toggleMode() {
  chessMode = !chessMode;
  if (chessMode) {
    initChessBoard();
    surface.setTitle("Chess vs AI");
  } else {
    initBoard();
    surface.setTitle("Checkers vs AI");
  }
}

boolean cWhite(int p) { return p > 0; }
int cType(int p) { return abs(p); }

CMove cm(int fr, int fc, int tr, int tc) {
  CMove m = new CMove();
  m.fr = fr; m.fc = fc; m.tr = tr; m.tc = tc;
  return m;
}

ArrayList<CMove> genBasicMoves(int[][] b, int r, int c) {
  ArrayList<CMove> out = new ArrayList<CMove>();
  int p = b[r][c];
  if (p == 0) return out;
  boolean white = cWhite(p);
  int type = cType(p);

  if (type == PAWN) {
    int dir = white ? -1 : 1;
    int startRow = white ? 6 : 1;
    if (inBounds(r + dir, c) && b[r + dir][c] == 0) {
      out.add(cm(r, c, r + dir, c));
      if (r == startRow && b[r + 2 * dir][c] == 0) out.add(cm(r, c, r + 2 * dir, c));
    }
    for (int dc = -1; dc <= 1; dc += 2) {
      int nr = r + dir, nc = c + dc;
      if (inBounds(nr, nc) && b[nr][nc] != 0 && cWhite(b[nr][nc]) != white) out.add(cm(r, c, nr, nc));
    }
  } else if (type == KNIGHT) {
    int[][] offs = {{-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}};
    for (int[] o : offs) {
      int nr = r + o[0], nc = c + o[1];
      if (inBounds(nr, nc) && (b[nr][nc] == 0 || cWhite(b[nr][nc]) != white)) out.add(cm(r, c, nr, nc));
    }
  } else if (type == KING) {
    for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      int nr = r + dr, nc = c + dc;
      if (inBounds(nr, nc) && (b[nr][nc] == 0 || cWhite(b[nr][nc]) != white)) out.add(cm(r, c, nr, nc));
    }
  } else {
    int[][] dirs;
    if (type == BISHOP) dirs = new int[][]{{-1,-1},{-1,1},{1,-1},{1,1}};
    else if (type == ROOK) dirs = new int[][]{{-1,0},{1,0},{0,-1},{0,1}};
    else dirs = new int[][]{{-1,-1},{-1,1},{1,-1},{1,1},{-1,0},{1,0},{0,-1},{0,1}};
    for (int[] d : dirs) {
      int nr = r + d[0], nc = c + d[1];
      while (inBounds(nr, nc)) {
        if (b[nr][nc] == 0) {
          out.add(cm(r, c, nr, nc));
        } else {
          if (cWhite(b[nr][nc]) != white) out.add(cm(r, c, nr, nc));
          break;
        }
        nr += d[0]; nc += d[1];
      }
    }
  }
  return out;
}

ArrayList<CMove> genSimpleMoves(int[][] b, boolean white) {
  ArrayList<CMove> out = new ArrayList<CMove>();
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = b[r][c];
    if (p == 0 || cWhite(p) != white) continue;
    out.addAll(genBasicMoves(b, r, c));
  }
  return out;
}

boolean isSquareAttacked(int[][] b, int r, int c, boolean byWhite) {
  for (int r2 = 0; r2 < SIZE; r2++) for (int c2 = 0; c2 < SIZE; c2++) {
    int p = b[r2][c2];
    if (p == 0 || cWhite(p) != byWhite) continue;
    int type = cType(p);
    if (type == PAWN) {
      int dir = byWhite ? -1 : 1;
      if (r2 + dir == r && abs(c2 - c) == 1) return true;
    } else {
      for (CMove m : genBasicMoves(b, r2, c2)) if (m.tr == r && m.tc == c) return true;
    }
  }
  return false;
}

int[] findKing(int[][] b, boolean white) {
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++)
    if (b[r][c] == (white ? KING : -KING)) return new int[]{r, c};
  return new int[]{-1, -1};
}

ArrayList<CMove> getLegalChessMoves(boolean white) {
  ArrayList<CMove> raw = new ArrayList<CMove>();
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = cboard[r][c];
    if (p == 0 || cWhite(p) != white) continue;
    raw.addAll(genBasicMoves(cboard, r, c));
  }

  if (epTargetR != -1) {
    int row = white ? 3 : 4;
    if (epPawnR == row) {
      for (int dc = -1; dc <= 1; dc += 2) {
        int c = epPawnC + dc;
        if (inBounds(row, c) && cboard[row][c] == (white ? PAWN : -PAWN)) {
          CMove m = cm(row, c, epTargetR, epTargetC);
          m.enPassant = true; m.epCapR = epPawnR; m.epCapC = epPawnC;
          raw.add(m);
        }
      }
    }
  }

  int homeRow = white ? 7 : 0;
  boolean kingMoved = white ? wKingMoved : bKingMoved;
  boolean rookAMoved = white ? wRookAMoved : bRookAMoved;
  boolean rookHMoved = white ? wRookHMoved : bRookHMoved;
  if (!kingMoved && cboard[homeRow][4] == (white ? KING : -KING) && !isSquareAttacked(cboard, homeRow, 4, !white)) {
    if (!rookHMoved && cboard[homeRow][7] == (white ? ROOK : -ROOK) && cboard[homeRow][5] == 0 && cboard[homeRow][6] == 0
        && !isSquareAttacked(cboard, homeRow, 5, !white) && !isSquareAttacked(cboard, homeRow, 6, !white)) {
      CMove m = cm(homeRow, 4, homeRow, 6); m.castleK = true; raw.add(m);
    }
    if (!rookAMoved && cboard[homeRow][0] == (white ? ROOK : -ROOK) && cboard[homeRow][1] == 0 && cboard[homeRow][2] == 0 && cboard[homeRow][3] == 0
        && !isSquareAttacked(cboard, homeRow, 3, !white) && !isSquareAttacked(cboard, homeRow, 2, !white)) {
      CMove m = cm(homeRow, 4, homeRow, 2); m.castleQ = true; raw.add(m);
    }
  }

  ArrayList<CMove> legal = new ArrayList<CMove>();
  for (CMove m : raw) {
    int[][] sim = copyBoard(cboard);
    simApplyCMove(sim, m);
    int[] k = findKing(sim, white);
    if (!isSquareAttacked(sim, k[0], k[1], !white)) legal.add(m);
  }
  return legal;
}

void simApplyCMove(int[][] b, CMove m) {
  int piece = b[m.fr][m.fc];
  b[m.fr][m.fc] = 0;
  if (m.enPassant) b[m.epCapR][m.epCapC] = 0;
  if (m.castleK) { b[m.fr][5] = b[m.fr][7]; b[m.fr][7] = 0; }
  if (m.castleQ) { b[m.fr][3] = b[m.fr][0]; b[m.fr][0] = 0; }
  if (cType(piece) == PAWN && (m.tr == 0 || m.tr == 7)) piece = cWhite(piece) ? QUEEN : -QUEEN;
  b[m.tr][m.tc] = piece;
}

void applyCMoveReal(CMove m) {
  int piece = cboard[m.fr][m.fc];
  boolean wasDoublePawn = cType(piece) == PAWN && abs(m.tr - m.fr) == 2;

  simApplyCMove(cboard, m);

  if (cType(piece) == KING) { if (cWhite(piece)) wKingMoved = true; else bKingMoved = true; }
  if (cType(piece) == ROOK) {
    if (m.fr == 7 && m.fc == 0) wRookAMoved = true;
    if (m.fr == 7 && m.fc == 7) wRookHMoved = true;
    if (m.fr == 0 && m.fc == 0) bRookAMoved = true;
    if (m.fr == 0 && m.fc == 7) bRookHMoved = true;
  }

  if (wasDoublePawn) {
    epTargetR = (m.fr + m.tr) / 2;
    epTargetC = m.fc;
    epPawnR = m.tr;
    epPawnC = m.fc;
  } else {
    epTargetR = -1; epTargetC = -1; epPawnR = -1; epPawnC = -1;
  }
}

float cEvaluate(int[][] b) {
  float score = 0;
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = b[r][c];
    if (p == 0) continue;
    int t = cType(p);
    float v;
    if (t == PAWN) v = 1;
    else if (t == KNIGHT) v = 3;
    else if (t == BISHOP) v = 3.1f;
    else if (t == ROOK) v = 5;
    else if (t == QUEEN) v = 9;
    else v = 1000;
    score += cWhite(p) ? -v : v;
  }
  return score;
}

float cMinimax(int[][] b, int depth, float alpha, float beta, boolean whiteToMove) {
  if (depth == 0) return cEvaluate(b);
  ArrayList<CMove> moves = genSimpleMoves(b, whiteToMove);
  if (moves.isEmpty()) return cEvaluate(b);

  if (!whiteToMove) {
    float best = -Float.MAX_VALUE;
    for (CMove m : moves) {
      int[][] nb = copyBoard(b);
      simApplyCMove(nb, m);
      float score = cMinimax(nb, depth - 1, alpha, beta, true);
      best = max(best, score);
      alpha = max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  } else {
    float best = Float.MAX_VALUE;
    for (CMove m : moves) {
      int[][] nb = copyBoard(b);
      simApplyCMove(nb, m);
      float score = cMinimax(nb, depth - 1, alpha, beta, false);
      best = min(best, score);
      beta = min(beta, best);
      if (beta <= alpha) break;
    }
    return best;
  }
}

void performCAIMove() {
  ArrayList<CMove> moves = getLegalChessMoves(false);
  if (moves.isEmpty()) {
    cGameOver = true;
    int[] k = findKing(cboard, false);
    cStatusMsg = isSquareAttacked(cboard, k[0], k[1], true) ? "Checkmate! You win." : "Stalemate - it's a draw.";
    return;
  }

  int depth = CHESS_DEPTHS[difficulty];
  float bestScore = -Float.MAX_VALUE, worstScore = Float.MAX_VALUE;
  CMove bestMove = moves.get(0), worstMove = moves.get(0);
  for (CMove m : moves) {
    int[][] nb = copyBoard(cboard);
    simApplyCMove(nb, m);
    float score = cMinimax(nb, depth - 1, -Float.MAX_VALUE, Float.MAX_VALUE, true);
    if (score > bestScore) { bestScore = score; bestMove = m; }
    if (score < worstScore) { worstScore = score; worstMove = m; }
  }

  CMove chosen = bestMove;
  if (random(1) < RANDOMNESS[difficulty]) chosen = moves.get(int(random(moves.size())));
  else if (random(1) < BLUNDER_CHANCE) chosen = worstMove;

  startCAnimation(chosen, false);
}

void startCAnimation(CMove m, boolean wasWhite) {
  cAnimMove = m;
  cAnimWasWhite = wasWhite;
  cAnimStepStart = millis();
  cAnimPieceType = cboard[m.fr][m.fc];
  cAnimating = true;
}

void updateCAnimation() {
  if (!cAnimating) return;
  if (millis() - cAnimStepStart >= CANIM_MS) finishCAnimatedMove();
}

void finishCAnimatedMove() {
  applyCMoveReal(cAnimMove);
  boolean wasWhite = cAnimWasWhite;
  cAnimating = false;
  cAnimMove = null;

  boolean nextWhite = !wasWhite;
  ArrayList<CMove> nextMoves = getLegalChessMoves(nextWhite);
  int[] k = findKing(cboard, nextWhite);
  boolean inCheck = isSquareAttacked(cboard, k[0], k[1], !nextWhite);

  if (nextMoves.isEmpty()) {
    cGameOver = true;
    if (inCheck) cStatusMsg = nextWhite ? "Checkmate! AI wins." : "Checkmate! You win.";
    else cStatusMsg = "Stalemate - it's a draw.";
    return;
  }

  whiteTurn = nextWhite;
  if (nextWhite) {
    cStatusMsg = inCheck ? "Check! Your move (white)" : "Your move (white)";
  } else {
    cStatusMsg = inCheck ? "Check! AI is thinking..." : "AI is thinking...";
    cAiPending = true;
    cAiPendingStart = millis();
  }
}

void drawCAnimPiece() {
  if (!cAnimating) return;
  float t = constrain((millis() - cAnimStepStart) / (float) CANIM_MS, 0, 1);
  float te = t * t * (3 - 2 * t);
  float cx = lerp(OFFX + cAnimMove.fc * CELL + CELL / 2.0f, OFFX + cAnimMove.tc * CELL + CELL / 2.0f, te);
  float cy = lerp(OFFY + cAnimMove.fr * CELL + CELL / 2.0f, OFFY + cAnimMove.tr * CELL + CELL / 2.0f, te);
  drawChessGlyph(cx, cy, cAnimPieceType);
}

void drawCPieces() {
  for (int r = 0; r < SIZE; r++) for (int c = 0; c < SIZE; c++) {
    int p = cboard[r][c];
    if (p == 0) continue;
    if (cAnimating && r == cAnimMove.fr && c == cAnimMove.fc) continue;
    float cx = OFFX + c * CELL + CELL / 2.0f;
    float cy = OFFY + r * CELL + CELL / 2.0f;
    drawChessGlyph(cx, cy, p);
  }
}

void drawChessGlyph(float cx, float cy, int p) {
  String[] letters = {"", "P", "N", "B", "R", "Q", "K"};
  noStroke();
  fill(0, 90);
  ellipse(cx + 3, cy + 4, CELL * 0.68f, CELL * 0.68f);
  fill(cWhite(p) ? color(240) : color(35));
  stroke(cWhite(p) ? color(90) : color(210));
  strokeWeight(2);
  ellipse(cx, cy, CELL * 0.68f, CELL * 0.68f);
  fill(cWhite(p) ? color(20) : color(235));
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(22);
  text(letters[cType(p)], cx, cy);
}

void drawCHighlights() {
  if (cSelR != -1) {
    noFill();
    stroke(80, 220, 255);
    strokeWeight(3);
    rect(OFFX + cSelC * CELL, OFFY + cSelR * CELL, CELL, CELL);

    noStroke();
    fill(80, 220, 255, 150);
    for (CMove m : cSelMoves) ellipse(OFFX + m.tc * CELL + CELL / 2.0f, OFFY + m.tr * CELL + CELL / 2.0f, 18, 18);
  }
}

void handleChessClick(int row, int col) {
  if (cSelR == -1) {
    ArrayList<CMove> all = getLegalChessMoves(true);
    ArrayList<CMove> forThis = new ArrayList<CMove>();
    for (CMove m : all) if (m.fr == row && m.fc == col) forThis.add(m);
    if (!forThis.isEmpty()) { cSelR = row; cSelC = col; cSelMoves = forThis; }
  } else {
    if (row == cSelR && col == cSelC) { cSelR = -1; cSelMoves.clear(); return; }
    CMove chosen = null;
    for (CMove m : cSelMoves) if (m.tr == row && m.tc == col) { chosen = m; break; }
    if (chosen != null) {
      cSelR = -1; cSelMoves.clear();
      startCAnimation(chosen, true);
    } else if (cboard[row][col] > 0) {
      ArrayList<CMove> all = getLegalChessMoves(true);
      ArrayList<CMove> forThis = new ArrayList<CMove>();
      for (CMove m : all) if (m.fr == row && m.fc == col) forThis.add(m);
      if (!forThis.isEmpty()) { cSelR = row; cSelC = col; cSelMoves = forThis; }
    }
  }
}
