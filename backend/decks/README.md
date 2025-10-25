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

POST api/quiz/start/<int:deck_id>/ [name='quiz-start'] This will start a quiz session and return a session_id which will be used for the following actions.
body example: {
  "mode": "random"
}

POST api/quiz/answer/<int:session_id>/ [name='quiz-answer'] Input an answer.
body example: {
  "answer": ""
}

POST api/quiz/pause/<int:session_id>/ [name='quiz-pause'] Pause the quiz session. 

POST api/quiz/resume/<int:session_id>/ [name='quiz-resume'] Resume the session and display the current question.

POST api/quiz/skip/<int:session_id>/ [name='quiz-skip'] Skip the current question and display the next question.

POST api/quiz/change_mode/<int:session_id>/ [name='quiz-change-mode'] This will change the mode to either random or sequential.
body example: {
  "mode": "random"
}

POST api/quiz/finish/<int:session_id>/ [name='quiz-finish'] This will end the session. 

GET api/quiz/results/<int:session_id>/ [name='quiz-results'] Show quiz results for a particular session.
