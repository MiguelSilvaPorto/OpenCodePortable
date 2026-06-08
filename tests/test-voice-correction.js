const http = require('http');

const systemPrompt = `Você é um robô de limpeza de transcrição de voz. Sua tarefa é APENAS remover gagueiras, palavras repetidas e hesitações (como "hã", "é", "tipo", "sabe").
Você NUNCA deve resumir, NUNCA deve encurtar e NUNCA deve alterar a frase do usuário. Mantenha todas as informações originais.

Exemplos:
Entrada: "Eu eu quero fazer um teste de de gravação."
Saída: "Eu quero fazer um teste de gravação."

Entrada: "tipo, eu queria saber se se a IA funciona sabe"
Saída: "Eu queria saber se a IA funciona"

Entrada: "Eu quero pesquisar como que o microfone do do do antigravity trabalha pois mesmo que eu fale alguma coisa errada ou alguma mensagem ou várias palavras repetidas ele ele corrige"
Saída: "Eu quero pesquisar como que o microfone do antigravity trabalha pois mesmo que eu fale alguma coisa errada ou alguma mensagem ou várias palavras repetidas ele corrige"

Responda APENAS com o texto limpo, sem aspas, sem explicações e mantendo a frase inteira sem encurtar.`;

function cleanAndCorrectVoiceText(rawText) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      model: 'llama3.2',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: rawText }
      ],
      stream: false,
      options: {
        temperature: 0.1
      }
    });

    const options = {
      hostname: 'localhost',
      port: 11434,
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.choices && json.choices[0] && json.choices[0].message) {
            resolve(json.choices[0].message.content.trim());
          } else {
            reject(new Error('Unexpected response format from Ollama'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', (e) => { reject(e); });
    req.write(postData);
    req.end();
  });
}

// Test cases mimicking typical user speech disfluency / mistakes
const testCases = [
  {
    input: "Eu eu quero criar criar um plano de implementação para... para tentar... tentar adicionar um microfone onde está o círculo vermelho.",
    expectedKeywords: ["plano de implementação", "microfone", "círculo vermelho"]
  },
  {
    input: "Eu quero pesquisar como que o microfone do do do antigravity trabalha pois mesmo que eu fale alguma coisa errada ou alguma mensagem ou várias palavras repetidas ele ele corrige",
    expectedKeywords: ["antigravity", "pesquisar", "corrige", "repetidas"]
  },
  {
    input: "Como a mensagem que eu estou enviando ela com certeza vai ser corrigida é é desse jeito que eu quero implementar.",
    expectedKeywords: ["mensagem", "corrigida", "implementar"]
  }
];

async function runTests() {
  console.log("=== Iniciando Teste de Normalização por Voz (Ollama / Llama3.2) ===");
  let passed = 0;
  
  for (let i = 0; i < testCases.length; i++) {
    const tc = testCases[i];
    console.log(`\nCaso de Teste ${i + 1}:`);
    console.log(`Entrada Bruta: "${tc.input}"`);
    
    try {
      const output = await cleanAndCorrectVoiceText(tc.input);
      console.log(`Saída Corrigida: "${output}"`);
      
      const containsKeywords = tc.expectedKeywords.every(kw => output.toLowerCase().includes(kw.toLowerCase()));
      if (containsKeywords) {
        console.log("-> PASSO: Correção semântica realizada com sucesso e palavras-chave mantidas.");
        passed++;
      } else {
        console.log("-> FALHOU: Algumas palavras-chave foram perdidas no filtro.");
      }
    } catch (e) {
      console.error("-> ERRO:", e.message);
    }
  }
  
  console.log(`\nResultado Final: ${passed}/${testCases.length} testes bem-sucedidos.`);
  process.exit(passed === testCases.length ? 0 : 1);
}

runTests();
