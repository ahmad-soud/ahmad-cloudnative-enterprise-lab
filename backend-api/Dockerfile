FROM python:3.9-slim

WORKDIR /code

COPY requirements.txt .


RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -u 10001 -m appuser && \
    chown -R appuser:appuser /code
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
