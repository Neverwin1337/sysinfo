const http = require('http');
const fs = require('fs');
const path = require('path');
const multiparty = require('multiparty');

// 确保 uploads 目录存在
const UPLOADS_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
    fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

const server = http.createServer((req, res) => {
    if (req.method === 'POST' && req.url === '/api/photo') {
        const form = new multiparty.Form();
        form.maxFiles = 1;
        form.parse(req, (err, fields, files) => {
            if (err) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Parse error' }));
                return;
            }

            const photo = files.file;
            if (!photo || !photo[0]) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'No file uploaded' }));
                return;
            }

            const file = photo[0];
            const filename = `photo_${Date.now()}.png`;
            const filepath = path.join(UPLOADS_DIR, filename);

            fs.move(file.path, filepath, (err) => {
                if (err) {
                    res.writeHead(500, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'Save failed' }));
                    return;
                }

                const meta = fields.metadata ? JSON.parse(fields.metadata[0]) : {};
                console.log(`\n📸 收到照片: ${filename}`);
                console.log(`   大小: ${file.size} bytes`);
                console.log(`   时间: ${new Date().toISOString()}`);
                if (meta.ip) console.log(`   IP: ${meta.ip}`);
                if (meta.userAgent) console.log(`   UA: ${meta.userAgent}`);

                // 记录元数据
                const record = {
                    filename,
                    size: file.size,
                    timestamp: new Date().toISOString(),
                    ...meta
                };
                fs.appendFile('photos.jsonl', JSON.stringify(record) + '\n', () => {});

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'ok', filename }));
            });
        });
    } else if (req.url === '/' || req.url === '/index.html') {
        serveFile(req, res, 'index.html', 'text/html');
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
});

function serveFile(req, res, filename, contentType) {
    const filePath = path.join(__dirname, filename);
    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(404);
            res.end('Not Found');
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`📷 摄像头拍照服务器运行中: http://0.0.0.0:${PORT}`);
    console.log(`📁 照片将保存至 uploads/ 目录`);
});
