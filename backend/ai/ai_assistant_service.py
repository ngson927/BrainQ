
import time
from openai import OpenAI
from django.utils import timezone
from decks.models import Deck, Flashcard
from .models import AIAssistantSession, AIAssistantMessage

client = OpenAI() 


class AIAssistantService:
    @staticmethod
    def _build_context_messages(session: AIAssistantSession, limit=10):
        messages = [
            {"role": msg.role, "content": msg.content}
            for msg in session.messages.order_by("created_at")[:limit]
        ]
        return messages

    @staticmethod
    def _build_deck_context(deck: Deck, max_flashcards=10):
        if not deck:
            return ""
        flashcards = Flashcard.objects.filter(deck=deck)[:max_flashcards]
        deck_info = f"Deck Title: {deck.title}\nDescription: {deck.description}\n"
        for c in flashcards:
            q = c.question.strip() if c.question else "No question"
            a = c.answer.strip() if c.answer else "No answer"
            deck_info += f"Q: {q}\nA: {a}\n"
        return deck_info.strip()

    @classmethod
    def handle_query(cls, session: AIAssistantSession, user_message: str):
        user_msg = AIAssistantMessage.objects.create(
            session=session, role="user", content=user_message
        )

        try:
            # Determine system prompt and model
            if session.deck:
                deck_context = cls._build_deck_context(session.deck)
                system_prompt = (
                    f"You are a study assistant helping the user learn based on this deck:\n\n"
                    f"{deck_context}\n\n"
                    "Answer user questions clearly and concisely, adapting to their learning level."
                ).strip()
                model_to_use = "gpt-4o-mini"
            else:
                system_prompt = (
                    "You are a friendly and knowledgeable AI study assistant. "
                    "The user may ask study tips, explanations, or general knowledge questions. "
                    "Respond helpfully, clearly, and conversationally."
                ).strip()
                model_to_use = "gpt-4o-mini"

            # Gather context
            history = cls._build_context_messages(session)
            messages = [{"role": "system", "content": system_prompt}] + history
            messages.append({"role": "user", "content": user_message})

            # Call OpenAI
            start_time = time.time()
            response = client.chat.completions.create(
                model=model_to_use,
                messages=messages,
                max_completion_tokens=500,
            )

        
            print("DEBUG OpenAI response:", response)

            content = (response.choices[0].message.content or "").strip()
            elapsed = int((time.time() - start_time) * 1000)

            if not content:
                content = "⚠️ Sorry, I couldn’t generate a response. Please try asking in a different way."

            assistant_msg = AIAssistantMessage.objects.create(
                session=session, role="assistant", content=content
            )

            return {
                "session_id": session.id,
                "user_message": user_msg.content,
                "assistant_message": assistant_msg.content,
                "response_time_ms": elapsed,
            }

        except Exception as e:
            fallback = f"⚠️ Sorry, I couldn’t process that request: {str(e)}"
            AIAssistantMessage.objects.create(
                session=session, role="assistant", content=fallback
            )
            return {
                "session_id": session.id,
                "user_message": user_msg.content,
                "assistant_message": fallback,
                "error": str(e),
            }

    @classmethod
    def start_session(cls, user, deck=None, title=None):
        session = AIAssistantSession.objects.create(
            user=user,
            deck=deck,
            title=title or (deck.title if deck else "General Study Session"),
        )
        return session

    @classmethod
    def end_session(cls, session: AIAssistantSession):
        session.is_active = False
        session.ended_at = timezone.now()
        session.save(update_fields=["is_active", "ended_at"])
        return session

    # ==============================================
    # 🔹 Session Control
    # ==============================================
    @classmethod
    def start_session(cls, user, deck=None, title=None):
        """Creates or resumes a chat session."""
        session = AIAssistantSession.objects.create(
            user=user,
            deck=deck,
            title=title or (deck.title if deck else "General Study Session"),
        )
        return session

    @classmethod
    def end_session(cls, session: AIAssistantSession):
        """Ends a chat session."""
        session.is_active = False
        session.ended_at = timezone.now()
        session.save(update_fields=["is_active", "ended_at"])
        return session
