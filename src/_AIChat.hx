// AI chat state data
@:structInit
class _AIChat extends _SaveObject
{
  public var needID: Int;
  public var needStringID: Int;
  public var aspectID: Int;
  public var emotion: Int;
  public var emotionID: _ChatEmotion;
  // NOTE: different from AI.eventID to not mess up NPCs
  public var eventID: String;
  public var clues: Int;
  public var consent: Int;
  public var stun: Int;
  public var fatigue: Int;
  public var timeout: Int;
  public var turns: Int;

  public function new(needID: Int, needStringID: Int,
      aspectID: Int, emotion: Int,
      emotionID: _ChatEmotion, eventID: String,
      clues: Int, consent: Int, stun: Int,
      fatigue: Int, timeout: Int, turns: Int)
    {
      this.needID = needID;
      this.needStringID = needStringID;
      this.aspectID = aspectID;
      this.emotion = emotion;
      this.emotionID = emotionID;
      this.eventID = eventID;
      this.clues = clues;
      this.consent = consent;
      this.stun = stun;
      this.fatigue = fatigue;
      this.timeout = timeout;
      this.turns = turns;
    }
}
