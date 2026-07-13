export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', 'https://conditionalaccess.tech');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const token = process.env.MATOMO_TOKEN;
  if (!token) {
    return res.status(500).json({ error: 'MATOMO_TOKEN not configured' });
  }

  const params = new URLSearchParams({
    module: 'API',
    method: 'VisitsSummary.getVisits',
    idSite: '1',
    period: 'month',
    date: 'today',
    format: 'json',
    token_auth: token,
  });

  const matomoRes = await fetch('https://conditionalaccesstech.matomo.cloud/index.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
    body: params.toString(),
  });

  const data = await matomoRes.json();
  res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate');
  return res.status(200).json(data);
}
