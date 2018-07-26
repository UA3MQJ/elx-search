# Search

Функции для поиска слов в наименованиях

## Installation

```elixir
def deps do
  [
    {:search, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
Search.PorterStemmerRu.stem("августа")
"август"
Search.PorterStemmerRu.stem("августе")
"август"
Search.PorterStemmer.stem("mans")
"man"
```
