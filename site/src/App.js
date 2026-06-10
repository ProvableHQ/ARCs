import './App.css';
import arcs from './arcs.json';
import React, { useState, useMemo, useCallback, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import { Card, Layout, Table, Tag } from 'antd';

const { Header, Content, Footer } = Layout;

const Readme = ({ readme }) => {
    return <ReactMarkdown source={readme} />;
}

function App() {
    const [body, setBody] = useState(null);

    const handleProposalClick = useCallback((id) => {
        const proposal = arcs[id].content;
        setBody(<Card>
            <h1>ARC-{id}: {arcs[id].metadata.title}</h1>
            <br/>
            <Readme readme={proposal}/>
        </Card>)
    }, []);

    const rows = useMemo(() => Object.values(arcs).map(proposal => {
        const { arc, title, authors, topic, status } = proposal.metadata;
        return { key: arc, arc, title, authors, topic, status }
    }), []);

    const columns = useMemo(() => [
        {
            title: 'ARC',
            dataIndex: 'arc',
            key: 'arc',
            sorter: true,
            render: arc => <a onClick={() => handleProposalClick(arc)}>{arc}</a>,
        },
        {
            title: 'Title',
            dataIndex: 'title',
            key: 'title',
        },
        {
            title: 'Authors',
            dataIndex: 'authors',
            key: 'authors',
        },
        {
            title: 'Topic',
            dataIndex: 'topic',
            key: 'topic',
            sorter: true,
            render: topic => {
                let tag = topic.toLowerCase();
                let color = 'green';
                if (tag === 'protocol') {
                    color = 'blue';
                } else if (tag === 'network') {
                    color = 'purple';
                } else if (tag === 'application') {
                    color = 'magenta';
                }
                return (
                    <Tag color={color} key={tag}>
                        {tag.toUpperCase()}
                    </Tag>
                );
            },
        },
        {
            title: 'Status',
            dataIndex: 'status',
            key: 'status',
            sorter: true,
        }
    ], [handleProposalClick]);

    useEffect(() => {
        if (!body) {
            setBody(<Table dataSource={rows} columns={columns} />);
        }
    }, [body, rows, columns]);

    return (
        <Layout className="layout">
            <Header className="header">
                <a onClick={() => setBody(<Table dataSource={rows} columns={columns} />)}><div className="logo"/></a>
            </Header>
            <Content style={{ padding: '50px 50px' }}>
                {body}
            </Content>
            <Footer style={{ textAlign: 'center' }}>Visit the <a href="https://github.com/AleoHQ/ARCs">ARCs Github repository</a>.</Footer>
        </Layout>
    );
}

export default App;
