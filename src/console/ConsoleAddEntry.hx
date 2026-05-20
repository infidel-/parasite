// console give command entry (one selectable named value)
package console;

typedef ConsoleAddEntry<T> =
{
  name: String,
  searchKey: String,
  value: T,
  ?aliases: Array<String>,
}
