typedef _PlayerAction =
{
  id: String, // action id
  name: String, // action name
  energy: Int, // energy to complete
  ?obj: Dynamic // bound object to act on
}
