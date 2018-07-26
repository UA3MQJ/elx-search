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
    # Затем в следующем порядке пробуем удалить окончания: ADJECTIVAL, VERB, NOUN.
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
      # Если слово оканчивается на нн — удаляем последнюю букву.
      t == true -> next_word
      "нн" == String.slice(word, -2..-1) -> String.slice(word, 0..-2)
      "ь" == String.slice(word, -1..-1) -> String.slice(word, 0..-2)
      true -> word
    end
  end


  # PERFECTIVE GERUND
  def perfective_gerund(word) do
    rv_word = rv(word)
    cond do
      # Группа 2: ив, ивши, ившись, ыв, ывши, ывшись.
      "ившись" == String.slice(rv_word, -6..-1) -> {true, {String.slice(word, 0..-7), String.slice(word, -6..-1)}}
      "ывшись" == String.slice(rv_word, -6..-1) -> {true, {String.slice(word, 0..-7), String.slice(word, -6..-1)}}
      "ивши"   == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}
      "ывши"   == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}
      "ив"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ыв"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      # Группа 1: в, вши, вшись.
      # Окончаниям из группы 1 должна предшествовать буква а или я.
      "авшись" == String.slice(rv_word, -6..-1) -> {true, {String.slice(word, 0..-6), String.slice(word, -5..-1)}}
      "явшись" == String.slice(rv_word, -6..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -5..-1)}}
      "авши"   == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "явши"   == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ав"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "яв"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      true -> {false, {word, ""}}
    end
  end

  # PARTICIPLE
  # Группа 1: ем, нн, вш, ющ, щ.
  # Группа 2: ивш, ывш, ующ.
  # Окончаниям из группы 1 должна предшествовать буква а или я.

  def participle(word) do
    rv_word = rv(word)
    cond do
      # Группа 2:
      "ивш"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ывш"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ующ"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      # Группа 1: в, вши, вшись.
      # Окончаниям из группы 1 должна предшествовать буква а или я.
      "аем"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яем"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "анн"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "янн"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "авш"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "явш"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ающ"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яющ"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ащ"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ящ"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      true -> {false, {word, ""}}
    end
  end


  # REFLEXIVE окончания ся, сь.
  def reflexive(word) do
    rv_word = rv(word)
    cond do
      "ся"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "сь"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      true -> {false, {word, ""}}
    end
  end

  # VERB
  # Группа 1: ла, на, ете, йте, ли, й, л, ем, н, ло, но, ет, ют, ны, ть, ешь, нно.
  # Группа 2: ила, ыла, ена, ейте, уйте, ите, или, ыли, ей, уй, ил, ыл, им, ым, ен, ило, ыло, ено, ят, ует, уют, ит, ыт, ены, ить, ыть, ишь, ую, ю.
  # Окончаниям из группы 1 должна предшествовать буква а или я.
  def verb(word) do
    rv_word = rv(word)
    cond do
      # Группа 2:
      "ейте"    == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}
      "уйте"    == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}     
      "ила"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ыла"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ена"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ите"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "или"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ыли"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ило"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ыло"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ено"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ует"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "уют"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ены"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ить"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ыть"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ишь"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ей"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "уй"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ил"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ыл"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "им"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ым"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ен"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ят"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ит"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ыт"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ую"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ю"       == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      # Группа 1:
      "аете"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "яете"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "айте"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "яйте"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "аешь"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "яешь"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "анно"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "янно"     == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ала"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яла"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ана"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яна"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "али"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яли"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "аем"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яем"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ало"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яло"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ано"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яно"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ает"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яет"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ают"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яют"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "аны"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яны"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ать"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ять"     == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ай"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "яй"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ал"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ял"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ан"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ян"      == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      true -> {false, {word, ""}}
    end
  end

  # NOUN
  # а, ев, ов, ие, ье, е, иями, ями, ами, еи, ии, и, ией, ей, ой, ий, й, иям, ям, ием, ем, ам, ом, о, у, ах, иях, ях, ы, ь, ию, ью, ю, ия, ья, я.
  def noun(word) do
    rv_word = rv(word)
    cond do
      "иями"   == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}
      "ями"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ами"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ией"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "иям"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ием"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "иях"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ям"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ев"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ов"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ие"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ье"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "еи"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ии"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ей"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ой"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ий"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ем"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ам"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ом"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ах"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ях"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ию"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ью"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ия"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ья"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "е"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "и"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "й"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "о"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "у"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ы"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ь"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "ю"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "а"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      "я"      == String.slice(rv_word, -1..-1) -> {true, {String.slice(word, 0..-2), String.slice(word, -1..-1)}}
      true -> {false, {word, ""}}
    end
  end

  # SUPERLATIVE
  # ейш, ейше.
  def superlative(word) do
    rv_word = rv(word)
    cond do
      "ейше"   == String.slice(rv_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}
      "ейш"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      true -> {false, {word, ""}}
    end
  end

  # DERIVATIONAL
  # ост, ость.
  def derivational(word) do
    r2_word = r2(word)
    cond do
      "ость"   == String.slice(r2_word, -4..-1) -> {true, {String.slice(word, 0..-5), String.slice(word, -4..-1)}}
      "ост"    == String.slice(r2_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      true -> {false, {word, ""}}
    end
  end

  # ADJECTIVE
  # ее, ие, ые, ое, ими, ыми, ей, ий, ый, ой, ем, им, ым, ом, его, ого, ему, ому, их, ых, ую, юю, ая, яя, ою, ею.
  def adjective(word) do
    rv_word = rv(word)
    cond do
      "ими"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ыми"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "его"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ого"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ему"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ому"    == String.slice(rv_word, -3..-1) -> {true, {String.slice(word, 0..-4), String.slice(word, -3..-1)}}
      "ее"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ие"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ые"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ое"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ей"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ий"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ый"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ой"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ем"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "им"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ым"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ом"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "их"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ых"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ую"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "юю"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ая"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "яя"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ою"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      "ею"     == String.slice(rv_word, -2..-1) -> {true, {String.slice(word, 0..-3), String.slice(word, -2..-1)}}
      true -> {false, {word, ""}}
    end
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

  # RV — область слова после первой гласной. Она может быть пустой, если гласные в слове отсутствуют.
  def rv(word) do
    first = vovels()
    |>Enum.map(fn(letter) -> substr_pos(word, letter) end)
    |>Enum.min()
    case first do
      false -> ""
      num -> String.slice(word, num..-1)
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

