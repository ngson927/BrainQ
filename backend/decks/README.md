Commands: 
POST api/decks/create/ to create a deck
body example: {
  "title": "My First Deck",
  "description": "A deck for testing flashcards",
  "is_public": true
}
deck number will be generated after creation

GET api/decks/list/ to get a list of decks created

POST api/flashcards/create/ to create flashcard

body example: {
  "deck": 1
  "question": "What is photosynthesis?",
  "answer": "The process plants use to convert sunlight into energy."
}
flashcard number will be generated after creation
GET api/flashcards/list/<deck number>/ To list flashcards created within a deck
GET api/flashcards/list/<deck number>/?shuffle=true/ to shuffle the order of cards
Rating system:
POST api/decks/<deckid>/feedback/ to create feedback
GET api/decks/<deckid>/feddbacks/ to view feedbacks 
body example: {
  "rating": 5 #rating 1-5 
  "comment" "this deck is well put together."

deck customization:
POST api/decks/create/ when creating a new deck
Patch api/decks/<deckid>/edit/ for already existing decks
body examples: {
  "theme": "dark
  "color": "black"
  text_color: "white"
  "card_order": "asc"}
