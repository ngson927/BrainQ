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

---
Search Feature

Endpoint:  
POST /api/search/ to search for a deck or a flashcard

Description  
Allows users to search across all decks and flashcards using a keyword.

Body Example:
{
  "query": "photosynthesis"
}
