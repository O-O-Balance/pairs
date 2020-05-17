module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Events as Events
import List.Extra as List
import Random
import Random.List as Random
import Set exposing (Set)
import Time


type alias Model =
    { state : State
    , numPairs : Int
    , cards : List Int
    , matched : Set Int
    }


type State
    = InProgress Phase
    | Solved


type Phase
    = Hidden
    | OneRevealed Int
    | TwoRevealed Int Int


type Msg
    = Click Int
    | TimeOut
    | Shuffle (List Int)
    | Restart


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init =
    always ( initialModel, shuffleCards initialModel.cards )


initialModel : Model
initialModel =
    let
        numPairs =
            10
    in
    { state = InProgress Hidden
    , numPairs = numPairs
    , cards = List.range 1 (numPairs * 2)
    , matched = Set.empty
    }


shuffleCards : List Int -> Cmd Msg
shuffleCards cards =
    Random.generate Shuffle (Random.shuffle cards)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TimeOut ->
            ( case model.state of
                InProgress (TwoRevealed _ _) ->
                    { model | state = InProgress Hidden }

                other ->
                    model
            , Cmd.none
            )

        Click card ->
            ( if Set.member card model.matched then
                model

              else
                case model.state of
                    InProgress Hidden ->
                        { model | state = InProgress (OneRevealed card) }

                    InProgress (OneRevealed card1) ->
                        let
                            matched =
                                if matching model card1 card then
                                    Set.insert card1 model.matched |> Set.insert card

                                else
                                    model.matched
                        in
                        if card == card1 then
                            model

                        else
                            { model
                                | state =
                                    if Set.size matched == model.numPairs * 2 then
                                        Solved

                                    else
                                        InProgress (TwoRevealed card1 card)
                                , matched = matched
                            }

                    other ->
                        model
            , Cmd.none
            )

        Restart ->
            ( { model | state = InProgress Hidden, matched = Set.empty }
            , shuffleCards model.cards
            )

        Shuffle cards ->
            ( { model | cards = cards }
            , Cmd.none
            )


matching : Model -> Int -> Int -> Bool
matching model card1 card2 =
    modBy (List.length model.cards // 2) card1 == modBy (List.length model.cards // 2) card2


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.state of
        InProgress (TwoRevealed _ _) ->
            Time.every 2000 (always TimeOut)

        other ->
            Sub.none


view : Model -> Html Msg
view model =
    let
        columns =
            calculateColumns (List.length model.cards)
    in
    Html.div []
        (createHeader model
            :: List.map (createRow model) (List.groupsOf columns model.cards)
        )


{-| Try for equal number of rows and columns,
favoring more columns if numCards is not a perfect square
-}
calculateColumns : Int -> Int
calculateColumns numCards =
    Maybe.withDefault numCards
        (List.find
            (\n -> modBy n numCards == 0)
            (List.range
                (numCards
                    |> toFloat
                    |> sqrt
                    |> ceiling
                )
                numCards
            )
        )


createHeader : Model -> Html Msg
createHeader model =
    Html.div []
        (case model.state of
            Solved ->
                [ Html.text "Congratulations!"
                , Html.button [ Events.onClick Restart ] [ Html.text "Play again" ]
                ]

            InProgress (TwoRevealed card1 card2) ->
                [ Html.text
                    (if matching model card1 card2 then
                        "A match!"

                     else
                        "Not a match, try again"
                    )
                ]

            other ->
                [ Html.text "Click on the cards to reveal them" ]
        )


createRow : Model -> List Int -> Html Msg
createRow model cards =
    Html.div [] (List.map (createButton model) cards)


createButton : Model -> Int -> Html Msg
createButton model card =
    Html.button
        [ Events.onClick (Click card)
        , Attrs.disabled
            (if Set.member card model.matched then
                True

             else
                case model.state of
                    InProgress (TwoRevealed _ _) ->
                        True

                    InProgress (OneRevealed card1) ->
                        card == card1

                    other ->
                        False
            )
        ]
        [ Html.text (buttonText model card) ]


buttonText : Model -> Int -> String
buttonText model number =
    let
        text =
            String.fromInt (modBy (List.length model.cards // 2) number)
    in
    if Set.member number model.matched then
        text

    else
        case model.state of
            InProgress (OneRevealed card1) ->
                if card1 == number then
                    text

                else
                    "X"

            InProgress (TwoRevealed card1 card2) ->
                if List.member number [ card1, card2 ] then
                    text

                else
                    "X"

            other ->
                "X"
