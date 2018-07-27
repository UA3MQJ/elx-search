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

## Links

  https://medium.com/@eigenein/%D1%81%D1%82%D0%B5%D0%BC%D0%BC%D0%B5%D1%80-%D0%BF%D0%BE%D1%80%D1%82%D0%B5%D1%80%D0%B0-%D0%B4%D0%BB%D1%8F-%D1%80%D1%83%D1%81%D1%81%D0%BA%D0%BE%D0%B3%D0%BE-%D1%8F%D0%B7%D1%8B%D0%BA%D0%B0-d41c38b2d340

  https://gist.github.com/eigenein/5418094

  https://tartarus.org/martin/PorterStemmer/

  https://tartarus.org/martin/PorterStemmer/porter.erl

  http://snowball.tartarus.org/algorithms/russian/stemmer.html
