defmodule Search.PorterStemmerRu do
  # https://medium.com/@eigenein/%D1%81%D1%82%D0%B5%D0%BC%D0%BC%D0%B5%D1%80-%D0%BF%D0%BE%D1%80%D1%82%D0%B5%D1%80%D0%B0-%D0%B4%D0%BB%D1%8F-%D1%80%D1%83%D1%81%D1%81%D0%BA%D0%BE%D0%B3%D0%BE-%D1%8F%D0%B7%D1%8B%D0%BA%D0%B0-d41c38b2d340
  # https://gist.github.com/eigenein/5418094
  # https://tartarus.org/martin/PorterStemmer/
  # https://tartarus.org/martin/PorterStemmer/porter.erl
  # http://snowball.tartarus.org/algorithms/russian/stemmer.html

  require Logger

  def stem(word) do
    cond do
      String.length(word) <= 2 -> word
      # Не обрабатывать слова, начинающиеся с большой буквы
      # чтобы не обрабатывать сокращения, аббревиатуры или имена
      word =~ ~r/^[А-Я]/u -> word # /u это для юникода
      true -> 
          word
          |> String.downcase()
          |> String.replace("ё", "е")
          |> step_1()
          |> step_2()
          |> step_3()
          |> step_4()
    end
  end

  # Шаг 1
  def step_1(word) do
    # Найти окончание PERFECTIVE GERUND. Если оно существует — удалить его и завершить этот шаг.
    {t1, {next_word1, _}} = perfective_gerund(word)
    # Иначе, удаляем окончание REFLEXIVE (если оно существует).
    {_t2, {next_word2, _}} = reflexive(next_word1)
    # # Затем в следующем порядке пробуем удалить окончания: ADJECTIVAL, VERB, NOUN.
    {t3, {next_word3, _}} = adjectiveval(next_word2)
    {t4, {next_word4, _}} = verb(next_word3)
    {t5, {next_word5, _}} = noun(next_word4)
    
    # Как только одно из них найдено — шаг завершается.
    cond do
      t1 == true -> next_word1
      t3 == true  -> next_word3
      t4 == true  -> next_word4
      t5 == true  -> next_word5
      true -> word        
    end
  end

  # Шаг 2
  # Если слово оканчивается на и — удаляем и.
  def step_2(word) do
    case "и" == String.slice(word, -1..-1) do
      true -> String.slice(word, 0..-2)
      false -> word
    end
  end

  # Шаг 3
  # Если в R2 найдется окончание DERIVATIONAL — удаляем его.
  def step_3(word) do
    {_t, {next_word, _}} = derivational(word)
    next_word
  end

  # Шаг 4
  # Возможен один из трех вариантов:
  def step_4(word) do
    {t, {next_word, _}} = superlative(word)
    cond do
      # TODO проверить
      # Если слово оканчивается на нн — удаляем последнюю букву.
      # Если слово оканчивается на SUPERLATIVE  —  удаляем его и снова удаляем последнюю букву, если слово оканчивается на нн.
      # Если слово оканчивается на ь — удаляем его.
      t == true -> next_word
      "нн" == String.slice(word, -2..-1) -> String.slice(word, 0..-2)
      "ь" == String.slice(word, -1..-1) -> String.slice(word, 0..-2)
      true -> word
    end
  end


  # PERFECTIVE GERUND
  # Группа 1: в, вши, вшись.
  # Группа 2: ив, ивши, ившись, ыв, ывши, ывшись.
  # Окончаниям из группы 1 должна предшествовать буква а или я.
  def perfective_gerund(word) do
    # {["а", "я"], "в"}, {["а", "я"], "вши"}, {["а", "я"], "вшись"},
    li_grp1 = ["в", "вши", "вшись"] |> Enum.map(&({["а", "я"], &1}))
    li_grp2 = ["ив", "ивши", "ившись", "ыв", "ывши", "ывшись"]
    li = li_grp1 ++ li_grp2
    word_ends(rv(word), word, li)
  end

  # PARTICIPLE
  # Группа 1: ем, нн, вш, ющ, щ.
  # Группа 2: ивш, ывш, ующ.
  # Окончаниям из группы 1 должна предшествовать буква а или я.
  def participle(word) do
    li_grp1 = ["ем", "нн", "вш", "ющ", "щ"] |> Enum.map(&({["а", "я"], &1}))
    li_grp2 = ["ивш", "ывш", "ующ"]
    li = li_grp1 ++ li_grp2
    word_ends(rv(word), word, li)
  end


  # REFLEXIVE окончания ся, сь.
  def reflexive(word) do
    word_ends(rv(word), word, ["ся", "сь"])
  end

  # VERB
  # Группа 1: ла, на, ете, йте, ли, й, л, ем, н, ло, но, ет, ют, ны, ть, ешь, нно.
  # Группа 2: ила, ыла, ена, ейте, уйте, ите, или, ыли, ей, уй, ил, ыл, им, ым, ен, ило, ыло, ено, ят, ует, уют, ит, ыт, ены, ить, ыть, ишь, ую, ю.
  # Окончаниям из группы 1 должна предшествовать буква а или я.
  def verb(word) do
    li_grp1 = ["ла", "на", "ете", "йте", "ли", "й", "л", "ем", "н", "ло", "но", "ет", "ют", "ны", "ть", "ешь", "нно"]
    |> Enum.map(&({["а", "я"], &1}))
    li_grp2 = ["ила", "ыла", "ена", "ейте", "уйте", "ите", "или", "ыли", "ей", "уй", "ил", "ыл", "им", "ым", "ен",
               "ило", "ыло", "ено", "ят", "ует", "уют", "ит", "ыт", "ены", "ить", "ыть", "ишь", "ую", "ю"]
    li = li_grp1 ++ li_grp2
    word_ends(rv(word), word, li)

  end

  # NOUN
  # а, ев, ов, ие, ье, е, иями, ями, ами, еи, ии, и, ией, ей, ой, ий, й, иям, ям, ием, ем, ам, ом, о, у, ах, иях, ях, ы, ь, ию, ью, ю, ия, ья, я.
  def noun(word) do
    li = ["а", "ев", "ов", "ие", "ье", "е", "иями", "ями", "ами", "еи", "ии", "и",
          "ией", "ей", "ой", "ий", "й", "иям", "ям", "ием", "ем", "ам", "ом", "о",
          "у", "ах", "иях", "ях", "ы", "ь", "ию", "ью", "ю", "ия", "ья", "я"]
    word_ends(rv(word), word, li)
  end

  # SUPERLATIVE
  # ейш, ейше.
  def superlative(word) do
    word_ends(rv(word), word, ["ейше", "ейш"])
  end

  # DERIVATIONAL
  # ост, ость.
  def derivational(word) do
    word_ends(r2(word), word, ["ость", "ост"])
  end

  # ADJECTIVE
  # ее, ие, ые, ое, ими, ыми, ей, ий, ый, ой, ем, им, ым, ом, его, ого, ему, ому, их, ых, ую, юю, ая, яя, ою, ею.
  def adjective(word) do
    li = ["ее", "ие", "ые", "ое", "ими", "ыми", "ей", "ий", "ый",
          "ой", "ем", "им", "ым", "ом", "его", "ого", "ему", "ому",
          "их", "ых", "ую", "юю", "ая", "яя", "ою", "ею"]
    word_ends(rv(word), word, li)
  end

  # ADJECTIVAL
  # ADJECTIVAL определяется как ADJECTIVE или PARTICIPLE + ADJECTIVE. 
  # Например: бегавшая = бега + вш + ая.
  def adjectiveval(word) do
    {t1, {next_word1, tail1}} = adjective(word)
    {t2, {next_word2, tail2}} = participle(next_word1)
    {t1 or t2, {next_word2, tail1<>tail2}} 
  end


  # При поиске окончания из всех возможных выбирается наиболее длинное. 
  # Например, в слове величие выбираем окончание ие, а не е.
  # 
  # Все проверки производятся над областью RV.
  # Так, при проверке на PERFECTIVE GERUND предшествующие буквы а и я также должны быть внутри RV. 
  # Буквы перед RV не участвуют в проверках вообще.


  # Гласные буквы — а, е, и, о, у, ы, э, ю, я. Буква ё считается равнозначной букве е.
  def vovels() do
    ["а", "е", "и", "о", "у", "ы", "э", "ю", "я"]
  end
  # количество гласных в слове
  def vovels_count(word) do
    word
    |> String.codepoints()
    |> Enum.map(fn(letter) -> letter in vovels() end)
    |> Enum.filter(fn(is_vov) -> is_vov end)
    |> length()
  end

  # RV — область слова после первой гласной. Она может быть пустой, если гласные в слове отсутствуют.
  def rv(word) do
    first = vovels()
    |>Enum.map(fn(letter) -> substr_pos(word, letter) end)
    |>Enum.min()
    case first do
      false -> ""
      num -> String.slice(word, (num+1)..-1)
    end
  end

  def r1(word) do
    r1_st(word, 0, word)
  end
  def r1_st(symbols, pos, word) do
    len = length(String.codepoints(symbols))
    case len > 1 do
      true ->
        a = String.slice(symbols, 0..0)
        b = String.slice(symbols, 1..1)
        a_is_vov = a in vovels()
        b_is_not_vov = not (b in vovels())
        case a_is_vov and b_is_not_vov do
          true ->  String.slice(word, (pos + 2)..-1)
          _else -> r1_st(String.slice(symbols, 1..-1), pos + 1, word)
        end
      _else ->
        ""
    end
  end

  def r2(word), do: r1(r1(word))

  # замена для
  # rv_word = rv(word)
  # cond do
  #   "ся"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
  #   "сь"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
  #   true -> {false, {word, ""}}
  # end
  #
  # word_ends(rv(word), word, ["ся", "сь"])
  #
  def word_ends(rv_word, word, ends_list) do
    word_ends_loop(rv_word, word, ends_list)
  end
  def word_ends_loop(_rv_word, word, []), do: {false, {word, ""}}
  def word_ends_loop(rv_word, word, [ends | tail] = _ends_list) do
    # "ими"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
    case ends do
      # окончание, которому предшествуют другие буквы
      {preends, ends2} ->
        {t, {new_word, new_tail}} = word_ends_loop2(rv_word, word, ends2, preends)
        case t do
          true -> {t, {new_word, new_tail}}
          false -> word_ends_loop(rv_word, word, tail)
        end
      # просто окончание
      ends2 ->
        elen = String.length(ends2) # длина окончания
        word_end = String.slice(rv_word, -(elen)..-1) # окончание слова
        case ends2==word_end do
          true ->
            {true, {String.slice(word, 0..-(elen+1)), String.slice(word, -(elen)..-1)}}
          false ->
            word_ends_loop(rv_word, word, tail)
        end
    end

  end
  def word_ends_loop2(_rv_word, word, _ends, []), do: {false, {word, ""}}
  def word_ends_loop2(rv_word, word, ends, [pre_end | tail] = _pre_ends_list) do
    {t, {new_word, new_tail}} = word_ends_loop(rv_word, word, [pre_end <> ends])
    case t do
      true ->
        {t, {new_word <> String.slice(new_tail, 0..0), String.slice(new_tail, 1..-1)}}
      false ->
        word_ends_loop2(rv_word, word, ends, tail)
    end
  end

  # поиск первого вхождения символа. нумеруются с ноля
  def substr_pos(str, substr) do
    case String.contains?(str, substr)  do
      true ->
        [x | _tail]=String.split(str, substr)
        String.length(x)
      _else ->
        false
    end
  end
end

